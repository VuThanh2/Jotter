using System.Buffers;
using System.Net.WebSockets;
using System.Security.Claims;
using Jotter.Application;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Jotter.Infrastructure;

// Bắt tay đã qua JwtBearer + policy Realtime (token scope "ws"). Một kết nối phục vụ nhiều note theo group noteId.
// Kết nối sống hàng giờ nên không giữ DI scope suốt vòng đời; mỗi lần join mở scope riêng để kiểm quyền.
public sealed class WebSocketHandler(
    NoteChannelRegistry registry,
    IServiceScopeFactory scopeFactory,
    ILogger<WebSocketHandler> logger)
{
    public const string Path = "/ws";

    // Policy bắt buộc token scope "ws"; Api gắn nó khi map endpoint này.
    public const string AuthorizationPolicy = "Realtime";

    private const int MaxMessageBytes = 4 * 1024;

    public async Task HandleAsync(HttpContext context)
    {
        if (!context.WebSockets.IsWebSocketRequest)
        {
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            return;
        }

        var principal = context.User;
        var ct = context.RequestAborted;

        var displayName = await LoadDisplayNameAsync(principal.GetUserId(), ct);
        using var socket = await context.WebSockets.AcceptWebSocketAsync();
        using var connection = new RealtimeConnection(socket, principal.GetUserId(), displayName);

        var closeStatus = WebSocketCloseStatus.NormalClosure;
        try
        {
            closeStatus = await ReceiveLoopAsync(connection, principal, ct);
        }
        catch (Exception ex) when (ex is WebSocketException or OperationCanceledException)
        {
            logger.LogDebug(ex, "Kết nối realtime {ConnectionId} bị ngắt.", connection.Id);
        }
        finally
        {
            foreach (var noteId in registry.LeaveAll(connection))
            {
                await registry.BroadcastPresenceAsync(noteId);
            }

            await CloseQuietlyAsync(socket, closeStatus);
        }
    }

    private async Task<WebSocketCloseStatus> ReceiveLoopAsync(
        RealtimeConnection connection,
        ClaimsPrincipal principal,
        CancellationToken ct)
    {
        var buffer = new ArrayBufferWriter<byte>(MaxMessageBytes);

        while (connection.Socket.State == WebSocketState.Open)
        {
            var result = await connection.Socket.ReceiveAsync(buffer.GetMemory(MaxMessageBytes), ct);
            if (result.MessageType == WebSocketMessageType.Close)
            {
                break;
            }

            buffer.Advance(result.Count);
            if (buffer.WrittenCount > MaxMessageBytes)
            {
                return WebSocketCloseStatus.MessageTooBig;
            }

            if (!result.EndOfMessage)
            {
                continue;
            }

            var message = RealtimeSerializer.TryDeserialize(buffer.WrittenSpan);
            buffer.ResetWrittenCount();

            if (!await HandleMessageAsync(connection, principal, message, ct))
            {
                return WebSocketCloseStatus.PolicyViolation;
            }
        }

        return WebSocketCloseStatus.NormalClosure;
    }

    // Trả false khi kết nối phải bị đóng.
    private async Task<bool> HandleMessageAsync(
        RealtimeConnection connection,
        ClaimsPrincipal principal,
        ClientMessage? message,
        CancellationToken ct)
    {
        switch (message)
        {
            case { Type: ClientMessage.Ping }:
                await connection.TrySendAsync(new PongMessage());
                return true;

            case { Type: ClientMessage.Join, NoteId: { } noteId }:
                return await JoinAsync(connection, principal, noteId, ct);

            case { Type: ClientMessage.Leave, NoteId: { } noteId }:
                if (registry.Leave(noteId, connection))
                {
                    await registry.BroadcastPresenceAsync(noteId);
                }

                return true;

            default:
                await connection.TrySendAsync(new ErrorMessage(ErrorMessage.Invalid));
                return true;
        }
    }

    // Không tin noteId client gửi: quyền đi qua đúng INoteAccessPolicy mà REST dùng. Phiên đăng nhập cũng được
    // kiểm lại, vì kết nối mở trước khi đăng xuất hay đổi mật khẩu không được join thêm note nào.
    private async Task<bool> JoinAsync(
        RealtimeConnection connection,
        ClaimsPrincipal principal,
        Guid noteId,
        CancellationToken ct)
    {
        await using var scope = scopeFactory.CreateAsyncScope();

        var sessionValidator = scope.ServiceProvider.GetRequiredService<SessionValidator>();
        var isSessionActive = principal.GetSecurityStamp() is { } securityStamp
            && await sessionValidator.IsActiveAsync(connection.UserId, principal.GetSessionId(), securityStamp, ct);

        if (!isSessionActive)
        {
            await connection.TrySendAsync(new ErrorMessage(ErrorMessage.Unauthorized, noteId));
            return false;
        }

        var accessPolicy = scope.ServiceProvider.GetRequiredService<INoteAccessPolicy>();
        var access = await accessPolicy.GetAccessAsync(connection.UserId, noteId, ct);

        // Tín hiệu không mang nội dung nên note đang khoá vẫn join được; nội dung vẫn bị chặn ở GET.
        if (!access.CanView)
        {
            await connection.TrySendAsync(new ErrorMessage(ErrorMessage.Forbidden, noteId));
            return true;
        }

        registry.Join(noteId, connection);
        await registry.BroadcastPresenceAsync(noteId);
        return true;
    }

    private async Task<string> LoadDisplayNameAsync(Guid userId, CancellationToken ct)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        return await db.Users
            .Where(u => u.Id == userId)
            .Select(u => u.DisplayName)
            .FirstOrDefaultAsync(ct) ?? string.Empty;
    }

    private static async Task CloseQuietlyAsync(WebSocket socket, WebSocketCloseStatus status)
    {
        if (socket.State is not (WebSocketState.Open or WebSocketState.CloseReceived))
        {
            return;
        }

        try
        {
            using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(2));
            await socket.CloseOutputAsync(status, statusDescription: null, timeout.Token);
        }
        catch (Exception ex) when (ex is WebSocketException or OperationCanceledException or InvalidOperationException)
        {
            // Client đã biến mất hoặc đang có lần gửi dở; không còn gì để đóng một cách lịch sự.
        }
    }
}

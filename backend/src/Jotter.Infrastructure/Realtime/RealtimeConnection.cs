using System.Net.WebSockets;

namespace Jotter.Infrastructure;

// Một socket của một thiết bị. WebSocket chỉ cho phép một lần gửi tại một thời điểm nên mọi lần gửi đi qua khoá.
public sealed class RealtimeConnection(WebSocket socket, Guid userId, string displayName) : IDisposable
{
    // Client chậm hoặc mất mạng không được giữ chân thao tác đang phát tín hiệu.
    private static readonly TimeSpan SendTimeout = TimeSpan.FromSeconds(5);

    private readonly SemaphoreSlim _sendLock = new(1, 1);

    public Guid Id { get; } = Guid.CreateVersion7();

    public Guid UserId { get; } = userId;

    public string DisplayName { get; } = displayName;

    public WebSocket Socket { get; } = socket;

    // Gửi thất bại không ném lỗi: kênh chỉ để tăng tốc, client sẽ tự đồng bộ lại khi kết nối lại.
    public async Task<bool> TrySendAsync(RealtimeMessage message)
    {
        if (Socket.State != WebSocketState.Open)
        {
            return false;
        }

        var payload = RealtimeSerializer.Serialize(message);
        using var timeout = new CancellationTokenSource(SendTimeout);

        try
        {
            await _sendLock.WaitAsync(timeout.Token);
            try
            {
                await Socket.SendAsync(payload, WebSocketMessageType.Text, endOfMessage: true, timeout.Token);
                return true;
            }
            finally
            {
                _sendLock.Release();
            }
        }
        catch (Exception ex) when (ex is WebSocketException or OperationCanceledException or ObjectDisposedException)
        {
            return false;
        }
    }

    public void Dispose() => _sendLock.Dispose();
}

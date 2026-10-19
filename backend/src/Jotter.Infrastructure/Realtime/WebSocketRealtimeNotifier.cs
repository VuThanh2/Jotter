using Jotter.Application;
using Jotter.Domain;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

// Gửi lỗi không bao giờ ném ra ngoài (RealtimeConnection.TrySendAsync), nên thao tác đã commit không bị ảnh hưởng.
public sealed class WebSocketRealtimeNotifier(
    AppDbContext db,
    NoteChannelRegistry registry,
    PendingRealtimeSignals pendingSignals) : IRealtimeNotifier
{
    public async Task NoteChangedAsync(Guid noteId, long version, Guid changedByUserId, CancellationToken ct)
    {
        var changedBy = await db.Users
            .Where(u => u.Id == changedByUserId)
            .Select(u => u.DisplayName)
            .FirstOrDefaultAsync(ct) ?? string.Empty;

        // Gửi cả cho các thiết bị khác của chính người sửa; client so version và bỏ qua nếu đã có.
        var message = new NoteChangedMessage(noteId, version, changedBy);
        await DispatchAsync(() => SendAsync(registry.Members(noteId), message));
    }

    public Task PermissionChangedAsync(
        Guid noteId,
        Guid recipientUserId,
        SharePermission permission,
        CancellationToken ct)
    {
        var message = new PermissionChangedMessage(noteId, permission);
        return DispatchAsync(() =>
            SendAsync(registry.Members(noteId).Where(c => c.UserId == recipientUserId), message));
    }

    // Quyền chỉ được kiểm lúc join nên phải chủ động đá ra; sau đó người bị thu hồi không nhận thêm tín hiệu nào.
    public Task AccessRevokedAsync(Guid noteId, Guid recipientUserId, CancellationToken ct) =>
        DispatchAsync(async () =>
        {
            await SendAsync(registry.RemoveUser(noteId, recipientUserId), new AccessRevokedMessage(noteId));
            await registry.BroadcastPresenceAsync(noteId);
        });

    // Đang trong transaction của IdempotencyScope thì hoãn tới lúc commit; ngoài transaction thì dữ liệu đã commit rồi.
    private Task DispatchAsync(Func<Task> signal)
    {
        if (db.Database.CurrentTransaction is null)
        {
            return signal();
        }

        pendingSignals.Enqueue(signal);
        return Task.CompletedTask;
    }

    private static async Task SendAsync(IEnumerable<RealtimeConnection> connections, RealtimeMessage message)
    {
        foreach (var connection in connections)
        {
            await connection.TrySendAsync(message);
        }
    }
}

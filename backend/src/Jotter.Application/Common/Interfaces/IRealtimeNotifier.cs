using Jotter.Domain;

namespace Jotter.Application;

// Chỉ phát tín hiệu, không mang nội dung. Gửi xuống socket thất bại không được làm hỏng thao tác đã commit.
public interface IRealtimeNotifier
{
    Task NoteChangedAsync(Guid noteId, long version, Guid changedByUserId, CancellationToken ct);

    Task PermissionChangedAsync(Guid noteId, Guid recipientUserId, SharePermission permission, CancellationToken ct);

    // Đá socket của người nhận khỏi group của note rồi đẩy accessRevoked — quyền chỉ được kiểm lúc join.
    Task AccessRevokedAsync(Guid noteId, Guid recipientUserId, CancellationToken ct);
}

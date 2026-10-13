using Jotter.Domain;

namespace Jotter.Application;

public sealed class RevokeShareCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    IShareGrantRepository shareGrants,
    IUnitOfWork unitOfWork,
    IRealtimeNotifier realtime,
    TimeProvider clock)
{
    public async Task<Result> ExecuteAsync(Guid noteId, Guid shareId, CancellationToken ct)
    {
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        if (!access.CanView)
        {
            return ShareErrors.NotFound;
        }

        var permission = access.EnsureOwner();
        if (permission.IsFailure)
        {
            return permission;
        }

        var grant = await shareGrants.GetByIdAsync(shareId, ct);
        if (grant is null || grant.NoteId != noteId)
        {
            return ShareErrors.NotFound;
        }

        // Tombstone chứ không xoá vật lý: lần sync kế tiếp của người nhận phải thấy bản ghi thu hồi để gỡ note khỏi máy họ.
        var revoked = grant.Revoke(clock.GetUtcNow());
        if (revoked.IsFailure)
        {
            return revoked;
        }

        await unitOfWork.SaveChangesAsync(ct);

        // Quyền chỉ được kiểm lúc join kênh nên phải chủ động đá người bị thu hồi ra, không chờ lần kiểm kế tiếp.
        await realtime.AccessRevokedAsync(noteId, grant.RecipientUserId, ct);

        return Result.Success();
    }
}

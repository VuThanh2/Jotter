using Jotter.Domain;

namespace Jotter.Application;

public sealed class ChangeSharePermissionCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    IShareGrantRepository shareGrants,
    IUnitOfWork unitOfWork,
    IRealtimeNotifier realtime)
{
    public async Task<Result<ChangeSharePermissionOutputDto>> ExecuteAsync(
        Guid noteId,
        Guid shareId,
        ChangeSharePermissionInputDto input,
        CancellationToken ct)
    {
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        if (!access.CanView)
        {
            return ShareErrors.NotFound;
        }

        var permission = access.EnsureOwner();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var grant = await shareGrants.GetByIdAsync(shareId, ct);
        if (grant is null || grant.NoteId != noteId)
        {
            return ShareErrors.NotFound;
        }

        var previousPermission = grant.Permission;

        var changed = grant.ChangePermission(input.Permission);
        if (changed.IsFailure)
        {
            return changed.Error;
        }

        await unitOfWork.SaveChangesAsync(ct);

        // Quyền ghi đã bị chặn ngay ở lần ghi kế tiếp; tín hiệu này để client bên kia thoát chế độ sửa mà không cần tải lại.
        if (grant.Permission != previousPermission)
        {
            await realtime.PermissionChangedAsync(noteId, grant.RecipientUserId, grant.Permission, ct);
        }

        return ShareMapper.ToChangeSharePermissionOutputDto(grant);
    }
}

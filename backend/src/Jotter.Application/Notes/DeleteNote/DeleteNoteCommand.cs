using Jotter.Domain;

namespace Jotter.Application;

public sealed class DeleteNoteCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    IShareGrantRepository shareGrants,
    IUnitOfWork unitOfWork,
    IRealtimeNotifier realtime,
    TimeProvider clock)
{
    public async Task<Result> ExecuteAsync(Guid noteId, CancellationToken ct)
    {
        // Edit là quyền trên nội dung; xoá là quyền trên vòng đời nên chỉ thuộc chủ sở hữu.
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureUnlockedOwner();
        if (permission.IsFailure)
        {
            return permission;
        }

        var note = await notes.GetByIdAsync(noteId, ct);
        if (note is null)
        {
            return NoteErrors.NotFound;
        }

        var activeGrants = await shareGrants.ListActiveByNoteAsync(noteId, ct);

        // Tombstone cả note lẫn attachment: chặn truy cập tệp ngay, còn bytes do FileCleanupJobService dọn.
        // Embedding được EmbeddingIndexerJobService gỡ ở lần quét kế tiếp.
        var now = clock.GetUtcNow();
        var deleted = note.MarkDeleted(now);
        if (deleted.IsFailure)
        {
            return deleted;
        }

        foreach (var grant in activeGrants)
        {
            grant.Revoke(now);
        }

        await unitOfWork.SaveChangesAsync(ct);

        foreach (var grant in activeGrants)
        {
            await realtime.AccessRevokedAsync(noteId, grant.RecipientUserId, ct);
        }

        return Result.Success();
    }
}

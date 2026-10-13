using Jotter.Domain;

namespace Jotter.Application;

public sealed class RemoveAttachmentCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result> ExecuteAsync(Guid attachmentId, CancellationToken ct)
    {
        // Route chỉ có attachmentId nên phải tìm note chủ quản trước rồi mới kiểm quyền được.
        var note = await notes.GetByAttachmentIdAsync(attachmentId, ct);
        if (note is null)
        {
            return NoteErrors.AttachmentNotFound;
        }

        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, note.Id, ct);
        if (!access.CanView)
        {
            return NoteErrors.AttachmentNotFound;
        }

        var permission = access.EnsureCanEditContent();
        if (permission.IsFailure)
        {
            return permission;
        }

        // Chỉ ghi tombstone; bytes do FileCleanupJobService dọn, tách khỏi transaction nghiệp vụ.
        var removed = note.RemoveAttachment(attachmentId, clock.GetUtcNow());
        if (removed.IsFailure)
        {
            return removed;
        }

        await unitOfWork.SaveChangesAsync(ct);

        return Result.Success();
    }
}

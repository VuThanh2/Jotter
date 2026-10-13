using Jotter.Domain;

namespace Jotter.Application;

public sealed class DownloadAttachmentQuery(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteQueryService noteQueries,
    IFileStorage storage)
{
    // Quyền được kiểm theo note chủ quản ngay trong mỗi lần tải, không phải một lần lúc ký URL.
    public async Task<Result<DownloadAttachmentOutputDto>> ExecuteAsync(Guid attachmentId, CancellationToken ct)
    {
        var attachment = await noteQueries.FindAttachmentAsync(attachmentId, ct);
        if (attachment is null)
        {
            return NoteErrors.AttachmentNotFound;
        }

        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, attachment.NoteId, ct);
        if (!access.CanView)
        {
            return NoteErrors.AttachmentNotFound;
        }

        var permission = access.EnsureCanReadContent();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var content = await storage.OpenReadAsync(attachment.StorageKey, ct);

        return new DownloadAttachmentOutputDto(content, attachment.FileName, attachment.MimeType, attachment.SizeBytes);
    }
}

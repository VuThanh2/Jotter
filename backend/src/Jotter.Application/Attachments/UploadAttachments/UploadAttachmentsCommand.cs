using System.Collections.Frozen;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class UploadAttachmentsCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    IFileTypeDetector fileTypes,
    IFileStorage storage,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    private const string UnknownMimeType = "application/octet-stream";

    // Note nhận cả "tệp tổng quát" nên không thể dùng danh sách trắng; chỉ chặn tệp thực thi.
    private static readonly FrozenSet<string> BlockedMimeTypes = new[]
    {
        "application/x-msdownload",
        "application/x-dosexec",
        "application/x-executable",
        "application/x-elf",
        "application/x-mach-binary",
        "application/x-sharedlib"
    }.ToFrozenSet(StringComparer.OrdinalIgnoreCase);

    public async Task<Result<UploadAttachmentsOutputDto>> ExecuteAsync(
        Guid noteId,
        UploadAttachmentsInputDto input,
        CancellationToken ct)
    {
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureCanEditContent();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var note = await notes.GetByIdAsync(noteId, ct);
        if (note is null)
        {
            return NoteErrors.NotFound;
        }

        // Cả lô thành công hoặc thất bại cùng nhau: mọi tệp qua hết bất biến Domain rồi mới ghi bytes,
        // để một tệp hỏng ở giữa lô không để lại bytes mồ côi của các tệp trước nó.
        var now = clock.GetUtcNow();
        var staged = new List<(Attachment Attachment, FileUploadDto File)>(input.Files.Count);

        foreach (var file in input.Files)
        {
            var mimeType = await ValidateAndDetectMimeTypeAsync(file, ct);
            if (mimeType.IsFailure)
            {
                return mimeType.Error.WithDetails("fileName", file.FileName);
            }

            var storageKey = $"attachments/{note.Id:N}/{Guid.CreateVersion7(now):N}";
            var added = note.AddAttachment(
                file.FileName,
                mimeType.Value,
                file.SizeBytes,
                storageKey,
                currentUser.UserId,
                now);

            if (added.IsFailure)
            {
                return added.Error.WithDetails("fileName", file.FileName);
            }

            staged.Add((added.Value, file));
        }

        // Ghi bytes trước khi commit metadata: commit lỗi thì chỉ còn bytes mồ côi để FileCleanupJobService dọn,
        // không bao giờ có metadata trỏ tới tệp không tồn tại.
        foreach (var (attachment, file) in staged)
        {
            await storage.SaveAsync(attachment.StorageKey, file.Content, ct);
        }

        await unitOfWork.SaveChangesAsync(ct);

        return new UploadAttachmentsOutputDto(
            staged.Select(entry => NoteMapper.ToUploadedAttachmentDto(entry.Attachment)).ToList());
    }

    private async Task<Result<string>> ValidateAndDetectMimeTypeAsync(FileUploadDto file, CancellationToken ct)
    {
        if (file.SizeBytes > Attachment.MaxSizeBytes)
        {
            return FileErrors.FileTooLarge;
        }

        var mimeType = await fileTypes.DetectMimeTypeAsync(file.Content, ct) ?? UnknownMimeType;

        return BlockedMimeTypes.Contains(mimeType) ? FileErrors.UnsupportedMediaType : mimeType;
    }
}

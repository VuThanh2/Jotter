namespace Jotter.Application;

public sealed record UploadAttachmentsInputDto(IReadOnlyList<FileUploadDto> Files);

public sealed record UploadAttachmentsOutputDto(IReadOnlyList<UploadedAttachmentDto> Items);

public sealed record UploadedAttachmentDto(
    Guid AttachmentId,
    string FileName,
    string MimeType,
    long SizeBytes,
    DateTimeOffset UploadedAt,
    long ChangeSeq);

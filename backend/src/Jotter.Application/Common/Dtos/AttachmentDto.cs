namespace Jotter.Application;

public sealed record AttachmentDto(
    Guid AttachmentId,
    string FileName,
    string MimeType,
    long SizeBytes,
    Guid UploadedBy,
    DateTimeOffset UploadedAt);

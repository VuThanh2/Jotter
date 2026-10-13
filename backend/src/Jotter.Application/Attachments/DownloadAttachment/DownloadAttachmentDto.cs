namespace Jotter.Application;

// Controller giữ quyền dispose Content sau khi stream xong cho client.
public sealed record DownloadAttachmentOutputDto(Stream Content, string FileName, string MimeType, long SizeBytes);

// Read model nội bộ giữa QueryService và Query: StorageKey không bao giờ được trả ra client.
public sealed record StoredAttachment(Guid NoteId, string FileName, string MimeType, long SizeBytes, string StorageKey);

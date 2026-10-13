using Jotter.Domain;

namespace Jotter.Application;

public sealed record PullChangesInputDto(long? Since, int? Limit);

public sealed record PullChangesOutputDto(
    IReadOnlyList<SyncNoteDto> Notes,
    IReadOnlyList<SyncLabelDto> Labels,
    IReadOnlyList<SyncShareDto> Shares,
    IReadOnlyList<SyncAttachmentDto> Attachments,
    long NextChangeSeq,
    bool HasMore,
    bool FullResyncRequired);

// Content và SearchContent luôn null khi note đang bảo vệ: nội dung đó không được nằm trong kho cục bộ.
// IsPinned, PinnedAt, LabelIds là của chủ sở hữu nên null với Recipient.
public sealed record SyncNoteDto(
    Guid NoteId,
    Guid OwnerId,
    Guid? ConflictOfNoteId,
    string Title,
    string? Content,
    string SearchTitle,
    string? SearchContent,
    bool? IsPinned,
    DateTimeOffset? PinnedAt,
    bool IsProtected,
    IReadOnlyList<Guid>? LabelIds,
    NoteAccessLevel Permission,
    long Version,
    long ChangeSeq,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? DeletedAt);

public sealed record SyncLabelDto(Guid LabelId, string Name, long ChangeSeq, DateTimeOffset? DeletedAt);

public sealed record SyncShareDto(
    Guid ShareId,
    Guid NoteId,
    Guid RecipientUserId,
    SharePermission Permission,
    DateTimeOffset SharedAt,
    DateTimeOffset? RevokedAt,
    long ChangeSeq);

public sealed record SyncAttachmentDto(
    Guid AttachmentId,
    Guid NoteId,
    string FileName,
    string MimeType,
    long SizeBytes,
    Guid UploadedBy,
    DateTimeOffset UploadedAt,
    DateTimeOffset? DeletedAt,
    long ChangeSeq);

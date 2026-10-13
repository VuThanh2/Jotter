namespace Jotter.Application;

// Permission chỉ là gợi ý cho UI; mọi endpoint ghi vẫn kiểm quyền lại.
public sealed record GetNoteOutputDto(
    Guid NoteId,
    Guid OwnerId,
    Guid? ConflictOfNoteId,
    string Title,
    string? Content,
    bool? IsPinned,
    DateTimeOffset? PinnedAt,
    bool IsProtected,
    IReadOnlyList<Guid>? LabelIds,
    IReadOnlyList<AttachmentDto> Attachments,
    bool SummaryAvailable,
    long Version,
    long ChangeSeq,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    NoteAccessLevel Permission);

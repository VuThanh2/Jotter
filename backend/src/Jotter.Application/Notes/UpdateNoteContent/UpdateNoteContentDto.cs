namespace Jotter.Application;

public sealed record UpdateNoteContentInputDto(long BaseVersion, string? Title, string? Content);

public sealed record UpdateNoteContentOutputDto(Guid NoteId, long Version, long ChangeSeq, DateTimeOffset UpdatedAt);

// Đi kèm VersionConflict để client giữ bản server ở note gốc và tách nội dung của mình thành Conflict Copy.
public sealed record ServerNoteDto(
    Guid NoteId,
    string Title,
    string Content,
    long Version,
    long ChangeSeq,
    DateTimeOffset UpdatedAt);

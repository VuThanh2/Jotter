namespace Jotter.Application;

// ConflictOfNoteId chỉ có khi client tạo Conflict Copy sau 409/403 — dùng chung endpoint tạo note, không cần endpoint riêng.
public sealed record CreateNoteInputDto(Guid NoteId, string? Title, string? Content, Guid? ConflictOfNoteId);

public sealed record CreateNoteOutputDto(
    Guid NoteId,
    Guid? ConflictOfNoteId,
    string Title,
    string Content,
    long Version,
    long ChangeSeq,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);

namespace Jotter.Application;

public enum NoteListScope
{
    Owned,
    Shared,
    All
}

public sealed record ListNotesInputDto(
    string? Q,
    Guid[]? LabelIds,
    NoteListScope? Scope,
    string? Cursor,
    int? Limit);

// IsPinned, PinnedAt và LabelIds là trạng thái riêng của chủ sở hữu: null với note được chia sẻ.
// Preview luôn rỗng với note đang bảo vệ, kể cả khi đã mở khoá, vì danh sách được cache xuống thiết bị.
public sealed record ListNotesItemDto(
    Guid NoteId,
    Guid? ConflictOfNoteId,
    string Title,
    string Preview,
    bool? IsPinned,
    DateTimeOffset? PinnedAt,
    bool IsProtected,
    bool IsShared,
    IReadOnlyList<Guid>? LabelIds,
    long Version,
    DateTimeOffset UpdatedAt);

// SearchText đã được chuẩn hoá bằng đúng thuật toán của client; rỗng nghĩa là không tìm kiếm.
public sealed record ListNotesFilter(NoteListScope Scope, string SearchText, IReadOnlyCollection<Guid> LabelIds);

public sealed record ListNotesCursor(bool IsPinned, DateTimeOffset? PinnedAt, DateTimeOffset UpdatedAt, Guid NoteId);

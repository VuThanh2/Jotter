using Jotter.Domain;

namespace Jotter.Application;

public sealed record ListSharedWithMeInputDto(string? Cursor, int? Limit);

// Không có nhãn và trạng thái ghim: đó là cách tổ chức riêng của chủ sở hữu.
public sealed record ListSharedWithMeItemDto(
    Guid NoteId,
    string Title,
    string Preview,
    bool IsProtected,
    SharePermission Permission,
    SharedByDto SharedBy,
    DateTimeOffset SharedAt,
    long Version,
    DateTimeOffset UpdatedAt);

public sealed record SharedByDto(Guid UserId, string DisplayName, string Email);

public sealed record ListSharedWithMeCursor(DateTimeOffset SharedAt, Guid NoteId);

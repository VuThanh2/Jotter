namespace Jotter.Application;

public sealed record GetMeOutputDto(
    Guid UserId,
    string Email,
    string DisplayName,
    string? AvatarUrl,
    bool IsActivated,
    DateTimeOffset CreatedAt);

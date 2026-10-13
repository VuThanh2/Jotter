namespace Jotter.Application;

public sealed record UpdateProfileInputDto(string DisplayName);

public sealed record UpdateProfileOutputDto(
    Guid UserId,
    string Email,
    string DisplayName,
    string? AvatarUrl,
    bool IsActivated);

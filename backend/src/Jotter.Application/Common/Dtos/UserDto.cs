namespace Jotter.Application;

public sealed record UserDto(Guid UserId, string Email, string DisplayName, bool IsActivated, string? AvatarUrl);

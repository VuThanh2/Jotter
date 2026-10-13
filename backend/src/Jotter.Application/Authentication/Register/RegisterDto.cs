namespace Jotter.Application;

public sealed record RegisterInputDto(string Email, string DisplayName, string Password, string ConfirmPassword);

public sealed record RegisterOutputDto(string AccessToken, DateTimeOffset ExpiresAt, UserDto User);

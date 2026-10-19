namespace Jotter.Application;

public sealed record ChangePasswordInputDto(string CurrentPassword, string NewPassword, string ConfirmPassword);

public sealed record ChangePasswordOutputDto(string AccessToken, DateTimeOffset ExpiresAt);

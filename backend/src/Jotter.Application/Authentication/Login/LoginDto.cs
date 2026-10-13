namespace Jotter.Application;

public sealed record LoginInputDto(string Email, string Password);

public sealed record LoginOutputDto(string AccessToken, DateTimeOffset ExpiresAt, UserDto User);

namespace Jotter.Application;

public sealed record ConfirmActivationInputDto(string Code);

public sealed record ConfirmActivationOutputDto(bool IsActivated, string AccessToken, DateTimeOffset ExpiresAt);

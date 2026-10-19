namespace Jotter.Application;

public sealed record VerifyResetCodeInputDto(string Email, string Code);

public sealed record VerifyResetCodeOutputDto(string ResetTicket, DateTimeOffset ExpiresAt);

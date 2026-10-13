namespace Jotter.Application;

public sealed record IssuedToken(string Value, DateTimeOffset ExpiresAt);

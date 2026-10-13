namespace Jotter.Application;

public sealed record IdempotentResponse(int StatusCode, string? ContentType, byte[] Body);

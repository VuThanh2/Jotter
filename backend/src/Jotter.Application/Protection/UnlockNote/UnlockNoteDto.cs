namespace Jotter.Application;

public sealed record UnlockNoteInputDto(string Password);

public sealed record UnlockNoteOutputDto(Guid UnlockSessionId, DateTimeOffset ExpiresAt);

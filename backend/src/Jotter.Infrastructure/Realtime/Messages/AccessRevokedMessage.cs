namespace Jotter.Infrastructure;

public sealed record AccessRevokedMessage(Guid NoteId) : RealtimeMessage("accessRevoked");

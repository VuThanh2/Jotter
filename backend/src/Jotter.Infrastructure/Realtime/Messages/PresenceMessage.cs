namespace Jotter.Infrastructure;

public sealed record PresenceMessage(Guid NoteId, IReadOnlyList<PresenceUser> Users) : RealtimeMessage("presence");

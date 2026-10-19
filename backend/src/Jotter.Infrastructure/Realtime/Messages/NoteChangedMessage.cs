namespace Jotter.Infrastructure;

public sealed record NoteChangedMessage(Guid NoteId, long Version, string By) : RealtimeMessage("noteChanged");

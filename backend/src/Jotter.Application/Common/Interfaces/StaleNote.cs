namespace Jotter.Application;

public sealed record StaleNote(Guid NoteId, string Title, string Content, long Version, bool IsDeleted);

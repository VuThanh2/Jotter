namespace Jotter.Application;

public sealed record GetNoteVersionOutputDto(Guid NoteId, long Version);

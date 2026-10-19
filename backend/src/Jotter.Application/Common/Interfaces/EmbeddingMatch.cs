namespace Jotter.Application;

public sealed record EmbeddingMatch(Guid NoteId, string NoteTitle, string ChunkText, float Score);

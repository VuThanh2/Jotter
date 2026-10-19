namespace Jotter.Domain;

public interface INoteUnlockSessionRepository
{
    Task<IReadOnlyList<NoteUnlockSession>> ListActiveAsync(
        Guid noteId,
        Guid userId,
        DateTimeOffset now,
        CancellationToken ct);

    Task<IReadOnlyList<NoteUnlockSession>> ListActiveByNoteAsync(Guid noteId, DateTimeOffset now, CancellationToken ct);

    Task<IReadOnlyList<NoteUnlockSession>> ListActiveByUserAsync(Guid userId, DateTimeOffset now, CancellationToken ct);

    void Add(NoteUnlockSession session);
}

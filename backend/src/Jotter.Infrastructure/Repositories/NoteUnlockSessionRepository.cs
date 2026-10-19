using Jotter.Domain;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class NoteUnlockSessionRepository(AppDbContext db) : INoteUnlockSessionRepository
{
    public async Task<IReadOnlyList<NoteUnlockSession>> ListActiveAsync(
        Guid noteId,
        Guid userId,
        DateTimeOffset now,
        CancellationToken ct) =>
        await db.NoteUnlockSessions
            .Where(s => s.NoteId == noteId && s.UserId == userId && s.ExpiresAt > now)
            .ToListAsync(ct);

    public async Task<IReadOnlyList<NoteUnlockSession>> ListActiveByNoteAsync(
        Guid noteId,
        DateTimeOffset now,
        CancellationToken ct) =>
        await db.NoteUnlockSessions.Where(s => s.NoteId == noteId && s.ExpiresAt > now).ToListAsync(ct);

    public async Task<IReadOnlyList<NoteUnlockSession>> ListActiveByUserAsync(
        Guid userId,
        DateTimeOffset now,
        CancellationToken ct) =>
        await db.NoteUnlockSessions.Where(s => s.UserId == userId && s.ExpiresAt > now).ToListAsync(ct);

    public void Add(NoteUnlockSession session) => db.NoteUnlockSessions.Add(session);
}

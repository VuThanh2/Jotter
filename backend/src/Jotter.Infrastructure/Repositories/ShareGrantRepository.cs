using Jotter.Domain;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class ShareGrantRepository(AppDbContext db) : IShareGrantRepository
{
    public Task<ShareGrant?> GetByIdAsync(Guid shareId, CancellationToken ct) =>
        db.ShareGrants.FirstOrDefaultAsync(g => g.Id == shareId, ct);

    public Task<bool> ExistsActiveAsync(Guid noteId, Guid recipientUserId, CancellationToken ct) =>
        db.ShareGrants.AnyAsync(
            g => g.NoteId == noteId && g.RecipientUserId == recipientUserId && g.RevokedAt == null,
            ct);

    public async Task<IReadOnlyList<ShareGrant>> ListActiveByNoteAsync(Guid noteId, CancellationToken ct) =>
        await db.ShareGrants.Where(g => g.NoteId == noteId && g.RevokedAt == null).ToListAsync(ct);

    public void Add(ShareGrant shareGrant) => db.ShareGrants.Add(shareGrant);
}

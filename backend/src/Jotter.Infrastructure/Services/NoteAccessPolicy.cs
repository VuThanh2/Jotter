using Jotter.Application;
using Jotter.Domain;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

// Thành phần DUY NHẤT định nghĩa luật truy cập note. Ngoài INoteAccessPolicy, nó còn cung cấp các IQueryable phạm vi
// để QueryService (danh sách, shared-with-me, sync) dựng truy vấn trên đúng luật này thay vì tự viết lại điều kiện.
public sealed class NoteAccessPolicy(AppDbContext db, TimeProvider clock) : INoteAccessPolicy
{
    public async Task<NoteAccess> GetAccessAsync(Guid userId, Guid noteId, CancellationToken ct)
    {
        var grants = ActiveGrantsFor(userId);
        var unlockSessions = ActiveUnlockSessionsOf(userId);

        var facts = await db.Notes
            .Where(n => n.Id == noteId && n.DeletedAt == null)
            .Select(n => new
            {
                IsOwner = n.OwnerId == userId,
                n.IsProtected,
                SharedPermission = grants
                    .Where(g => g.NoteId == n.Id)
                    .Select(g => (SharePermission?)g.Permission)
                    .FirstOrDefault(),
                HasActiveUnlockSession = unlockSessions.Any(s => s.NoteId == n.Id)
            })
            .FirstOrDefaultAsync(ct);

        if (facts is null)
        {
            return NoteAccess.None;
        }

        var level = facts.IsOwner
            ? NoteAccessLevel.Owner
            : facts.SharedPermission switch
            {
                SharePermission.Edit => NoteAccessLevel.Edit,
                SharePermission.ReadOnly => NoteAccessLevel.ReadOnly,
                _ => NoteAccessLevel.None
            };

        return level == NoteAccessLevel.None
            ? NoteAccess.None
            : new NoteAccess(level, facts.IsProtected, facts.HasActiveUnlockSession);
    }

    public async Task<IReadOnlyList<Guid>> ListContentReadableNoteIdsAsync(Guid userId, CancellationToken ct)
    {
        var unlockSessions = ActiveUnlockSessionsOf(userId);

        return await VisibleNotes(userId)
            .Where(n => !n.IsProtected || unlockSessions.Any(s => s.NoteId == n.Id))
            .Select(n => n.Id)
            .ToListAsync(ct);
    }

    public IQueryable<Note> OwnedNotes(Guid userId) =>
        db.Notes.Where(n => n.OwnerId == userId && n.DeletedAt == null);

    public IQueryable<Note> SharedNotes(Guid userId)
    {
        var grants = ActiveGrantsFor(userId);
        return db.Notes.Where(n => n.DeletedAt == null && grants.Any(g => g.NoteId == n.Id));
    }

    public IQueryable<Note> VisibleNotes(Guid userId)
    {
        var grants = ActiveGrantsFor(userId);
        return db.Notes.Where(n => n.DeletedAt == null && (n.OwnerId == userId || grants.Any(g => g.NoteId == n.Id)));
    }

    public IQueryable<ShareGrant> ActiveGrantsFor(Guid userId) =>
        db.ShareGrants.Where(g => g.RecipientUserId == userId && g.RevokedAt == null);

    // Phạm vi đối chiếu nội dung của note đang bảo vệ phụ thuộc phiên mở khoá, đánh giá ngay lúc truy vấn.
    public IQueryable<NoteUnlockSession> ActiveUnlockSessionsOf(Guid userId)
    {
        var now = clock.GetUtcNow();
        return db.NoteUnlockSessions.Where(s => s.UserId == userId && s.ExpiresAt > now);
    }
}

using Jotter.Application;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class ShareQueryService(AppDbContext db, NoteAccessPolicy accessPolicy) : IShareQueryService
{
    public async Task<IReadOnlyList<ListSharesItemDto>> ListByNoteAsync(Guid noteId, CancellationToken ct) =>
        await db.ShareGrants
            .Where(g => g.NoteId == noteId && g.RevokedAt == null)
            .Join(db.Users, g => g.RecipientUserId, u => u.Id, (g, u) => new { Grant = g, Recipient = u })
            .OrderBy(x => x.Grant.SharedAt)
            .Select(x => new ListSharesItemDto(
                x.Grant.Id,
                x.Recipient.Id,
                x.Recipient.Email!,
                x.Recipient.DisplayName,
                x.Grant.Permission,
                x.Grant.SharedAt))
            .ToListAsync(ct);

    // Không trả nhãn và trạng thái ghim của chủ sở hữu; grant đã thu hồi và note đã xoá tự biến mất khỏi danh sách.
    public async Task<IReadOnlyList<ListSharedWithMeItemDto>> ListSharedWithMeAsync(
        Guid recipientUserId,
        ListSharedWithMeCursor? after,
        int take,
        CancellationToken ct)
    {
        var rows = accessPolicy.ActiveGrantsFor(recipientUserId)
            .Join(
                db.Notes.Where(n => n.DeletedAt == null),
                g => g.NoteId,
                n => n.Id,
                (g, n) => new { Grant = g, Note = n })
            .Join(db.Users, x => x.Note.OwnerId, u => u.Id, (x, u) => new { x.Grant, x.Note, Owner = u });

        if (after is not null)
        {
            rows = rows.Where(x =>
                x.Grant.SharedAt < after.SharedAt
                || (x.Grant.SharedAt == after.SharedAt && x.Note.Id.CompareTo(after.NoteId) < 0));
        }

        return await rows
            .OrderByDescending(x => x.Grant.SharedAt)
            .ThenByDescending(x => x.Note.Id)
            .Take(take)
            .Select(x => new ListSharedWithMeItemDto(
                x.Note.Id,
                x.Note.Title,
                x.Note.IsProtected ? string.Empty : x.Note.Content.Substring(0, NoteQueryService.PreviewLength),
                x.Note.IsProtected,
                x.Grant.Permission,
                new SharedByDto(x.Owner.Id, x.Owner.DisplayName, x.Owner.Email!),
                x.Grant.SharedAt,
                x.Note.Version,
                x.Note.UpdatedAt))
            .ToListAsync(ct);
    }
}

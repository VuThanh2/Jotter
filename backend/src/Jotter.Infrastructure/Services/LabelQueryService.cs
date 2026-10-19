using Jotter.Application;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class LabelQueryService(AppDbContext db) : ILabelQueryService
{
    public async Task<IReadOnlyList<ListLabelsItemDto>> ListAsync(Guid ownerId, CancellationToken ct) =>
        await db.Labels
            .Where(l => l.OwnerId == ownerId && l.DeletedAt == null)
            .OrderBy(l => l.Name)
            .Select(l => new ListLabelsItemDto(
                l.Id,
                l.Name,
                db.Notes.Count(n => n.DeletedAt == null && n.Labels.Any(link => link.LabelId == l.Id)),
                l.ChangeSeq))
            .ToListAsync(ct);
}

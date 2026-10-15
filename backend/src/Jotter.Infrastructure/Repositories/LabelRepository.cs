using Jotter.Domain;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class LabelRepository(AppDbContext db) : ILabelRepository
{
    public Task<Label?> GetByIdAsync(Guid labelId, CancellationToken ct) =>
        db.Labels.FirstOrDefaultAsync(l => l.Id == labelId, ct);

    public Task<bool> ExistsAsync(Guid labelId, CancellationToken ct) =>
        db.Labels.AnyAsync(l => l.Id == labelId, ct);

    // Hạ chữ thường ở cả hai vế trong SQL để cùng một hàm lower() của Postgres quyết định.
    public Task<bool> IsNameTakenAsync(Guid ownerId, string name, Guid? excludedLabelId, CancellationToken ct) =>
        db.Labels.AnyAsync(
            l => l.OwnerId == ownerId
                && l.DeletedAt == null
                && l.Id != excludedLabelId
                && l.Name.ToLower() == name.ToLower(),
            ct);

    public async Task<bool> AreAllActiveAndOwnedByAsync(
        Guid ownerId,
        IReadOnlyCollection<Guid> labelIds,
        CancellationToken ct)
    {
        if (labelIds.Count == 0)
        {
            return true;
        }

        var distinctIds = labelIds.Distinct().ToList();
        var matched = await db.Labels.CountAsync(
            l => distinctIds.Contains(l.Id) && l.OwnerId == ownerId && l.DeletedAt == null,
            ct);

        return matched == distinctIds.Count;
    }

    public void Add(Label label) => db.Labels.Add(label);
}

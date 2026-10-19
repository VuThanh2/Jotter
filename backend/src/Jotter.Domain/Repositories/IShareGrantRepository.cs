namespace Jotter.Domain;

public interface IShareGrantRepository
{
    Task<ShareGrant?> GetByIdAsync(Guid shareId, CancellationToken ct);

    Task<bool> ExistsActiveAsync(Guid noteId, Guid recipientUserId, CancellationToken ct);

    Task<IReadOnlyList<ShareGrant>> ListActiveByNoteAsync(Guid noteId, CancellationToken ct);

    void Add(ShareGrant shareGrant);
}

using Jotter.Domain;

namespace Jotter.Application;

public sealed class ListSharesQuery(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    IShareQueryService shareQueries)
{
    public async Task<Result<ListSharesOutputDto>> ExecuteAsync(Guid noteId, CancellationToken ct)
    {
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureOwner();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var shares = await shareQueries.ListByNoteAsync(noteId, ct);

        return new ListSharesOutputDto(shares);
    }
}

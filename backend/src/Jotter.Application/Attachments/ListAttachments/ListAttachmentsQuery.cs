using Jotter.Domain;

namespace Jotter.Application;

public sealed class ListAttachmentsQuery(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteQueryService noteQueries)
{
    public async Task<Result<ListAttachmentsOutputDto>> ExecuteAsync(Guid noteId, CancellationToken ct)
    {
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureCanReadContent();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var attachments = await noteQueries.ListAttachmentsAsync(noteId, ct);

        return new ListAttachmentsOutputDto(attachments);
    }
}

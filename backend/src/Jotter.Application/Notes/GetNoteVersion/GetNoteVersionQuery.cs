using Jotter.Domain;

namespace Jotter.Application;

// Polling dự phòng khi WebSocket không dùng được. Không trả nội dung nên không cần mở khoá.
public sealed class GetNoteVersionQuery(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteQueryService noteQueries)
{
    public async Task<Result<GetNoteVersionOutputDto>> ExecuteAsync(Guid noteId, CancellationToken ct)
    {
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureCanView();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var version = await noteQueries.GetVersionAsync(noteId, ct);
        if (version is null)
        {
            return NoteErrors.NotFound;
        }

        return new GetNoteVersionOutputDto(noteId, version.Value);
    }
}

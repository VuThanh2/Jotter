using Jotter.Domain;

namespace Jotter.Application;

public sealed class GetNoteQuery(ICurrentUser currentUser, INoteAccessPolicy accessPolicy, INoteQueryService noteQueries)
{
    public async Task<Result<GetNoteOutputDto>> ExecuteAsync(Guid noteId, CancellationToken ct)
    {
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureCanView();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var note = await noteQueries.GetAsync(noteId, access, ct);
        if (note is null)
        {
            return NoteErrors.NotFound;
        }

        // 423 vẫn kèm metadata (đã bỏ content) để client hiện tiêu đề và màn hình mở khoá.
        if (access.IsLocked)
        {
            return AccessErrors.NoteLocked.WithDetails("note", note);
        }

        return note;
    }
}

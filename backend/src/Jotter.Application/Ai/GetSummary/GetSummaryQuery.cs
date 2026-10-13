using Jotter.Domain;

namespace Jotter.Application;

// Tóm tắt không mang changeSeq nên luôn được đọc trực tiếp từ server, không cache cục bộ.
public sealed class GetSummaryQuery(ICurrentUser currentUser, INoteAccessPolicy accessPolicy, INoteQueryService noteQueries)
{
    public async Task<Result<GetSummaryOutputDto>> ExecuteAsync(Guid noteId, CancellationToken ct)
    {
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureCanReadContent();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var summary = await noteQueries.GetSummaryAsync(noteId, ct);
        if (summary is null)
        {
            return NoteErrors.SummaryNotFound;
        }

        return summary;
    }
}

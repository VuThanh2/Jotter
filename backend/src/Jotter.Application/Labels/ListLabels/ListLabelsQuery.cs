using Jotter.Domain;

namespace Jotter.Application;

public sealed class ListLabelsQuery(ICurrentUser currentUser, ILabelQueryService labelQueries)
{
    public async Task<Result<ListLabelsOutputDto>> ExecuteAsync(CancellationToken ct)
    {
        var labels = await labelQueries.ListAsync(currentUser.UserId, ct);

        return new ListLabelsOutputDto(labels);
    }
}

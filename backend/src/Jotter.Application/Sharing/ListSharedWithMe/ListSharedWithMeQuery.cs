using Jotter.Domain;

namespace Jotter.Application;

public sealed class ListSharedWithMeQuery(ICurrentUser currentUser, IShareQueryService shareQueries)
{
    public const int DefaultLimit = 20;
    public const int MaxLimit = 100;

    public async Task<Result<CursorPage<ListSharedWithMeItemDto>>> ExecuteAsync(
        ListSharedWithMeInputDto input,
        CancellationToken ct)
    {
        if (!PageCursor.TryDecode<ListSharedWithMeCursor>(input.Cursor, out var after))
        {
            return InputErrors.InvalidCursor;
        }

        var limit = input.Limit ?? DefaultLimit;
        var fetched = await shareQueries.ListSharedWithMeAsync(currentUser.UserId, after, limit + 1, ct);

        return CursorPage<ListSharedWithMeItemDto>.FromOverfetched(
            fetched,
            limit,
            item => new ListSharedWithMeCursor(item.SharedAt, item.NoteId));
    }
}

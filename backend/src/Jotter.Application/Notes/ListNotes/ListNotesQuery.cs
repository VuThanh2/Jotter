using Jotter.Domain;

namespace Jotter.Application;

public sealed class ListNotesQuery(ICurrentUser currentUser, INoteQueryService noteQueries)
{
    public const int DefaultLimit = 20;
    public const int MaxLimit = 100;

    public async Task<Result<CursorPage<ListNotesItemDto>>> ExecuteAsync(ListNotesInputDto input, CancellationToken ct)
    {
        if (!PageCursor.TryDecode<ListNotesCursor>(input.Cursor, out var after))
        {
            return InputErrors.InvalidCursor;
        }

        // Màn hình chính mặc định chỉ hiện note của mình; note được chia sẻ có khu vực riêng.
        // Từ khoá được chuẩn hoá bằng đúng thuật toán của client để kết quả online và offline trùng nhau.
        var filter = new ListNotesFilter(
            input.Scope ?? NoteListScope.Owned,
            SearchText.Normalize(input.Q),
            input.LabelIds?.Distinct().ToList() ?? []);

        var limit = input.Limit ?? DefaultLimit;
        var fetched = await noteQueries.ListAsync(currentUser.UserId, filter, after, limit + 1, ct);

        return CursorPage<ListNotesItemDto>.FromOverfetched(
            fetched,
            limit,
            note => new ListNotesCursor(note.IsPinned ?? false, note.PinnedAt, note.UpdatedAt, note.NoteId));
    }
}

namespace Jotter.Application;

public sealed record CursorPage<T>(IReadOnlyList<T> Items, string? NextCursor)
{
    // QueryService lấy dư một phần tử (limit + 1) chỉ để biết còn trang sau hay không.
    public static CursorPage<T> FromOverfetched<TKey>(IReadOnlyList<T> fetched, int limit, Func<T, TKey> keyOf)
    {
        if (fetched.Count <= limit)
        {
            return new CursorPage<T>(fetched, NextCursor: null);
        }

        var items = fetched.Take(limit).ToList();
        return new CursorPage<T>(items, PageCursor.Encode(keyOf(items[^1])));
    }
}

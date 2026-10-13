using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class PaginationTests
{
    [Fact]
    public void FromOverfetched_WhenNoExtraItemWasFetched_HasNoNextPage()
    {
        var page = CursorPage<int>.FromOverfetched([1, 2, 3], limit: 3, item => new Key(item));

        Assert.Equal(new[] { 1, 2, 3 }, page.Items);
        Assert.Null(page.NextCursor);
    }

    // Cursor phải trỏ vào phần tử cuối được TRẢ VỀ; trỏ vào phần tử dư sẽ làm trang sau bỏ sót nó.
    [Fact]
    public void FromOverfetched_DropsExtraItem_AndPointsCursorAtLastReturnedItem()
    {
        var page = CursorPage<int>.FromOverfetched([1, 2, 3, 4], limit: 3, item => new Key(item));

        Assert.Equal(new[] { 1, 2, 3 }, page.Items);
        Assert.True(PageCursor.TryDecode<Key>(page.NextCursor, out var key));
        Assert.Equal(new Key(3), key);
    }

    [Fact]
    public void TryDecode_MissingCursor_MeansFirstPage()
    {
        Assert.True(PageCursor.TryDecode<Key>(null, out var key));
        Assert.Null(key);
    }

    [Theory]
    [InlineData("không phải base64 !!")]
    [InlineData("bnVsbA")]  // base64url của "null"
    [InlineData("WzEsMl0")] // base64url của "[1,2]"
    public void TryDecode_RejectsTamperedCursor(string cursor)
    {
        Assert.False(PageCursor.TryDecode<Key>(cursor, out _));
    }

    public sealed record Key(int Value);
}

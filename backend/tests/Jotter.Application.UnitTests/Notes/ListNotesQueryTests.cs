using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class ListNotesQueryTests
{
    private readonly Guid _userId = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly INoteQueryService _noteQueries = Substitute.For<INoteQueryService>();

    public ListNotesQueryTests() => _currentUser.UserId.Returns(_userId);

    // Online phải chuẩn hoá đúng như offline (Drift): cùng từ khoá phải ra cùng kết quả dù có mạng hay không.
    [Fact]
    public async Task SearchTerm_IsNormalizedWithSharedAlgorithm_AndDefaultsToOwnedScope()
    {
        ListNotesFilter? filter = null;
        var take = 0;
        _noteQueries
            .ListAsync(
                _userId,
                Arg.Do<ListNotesFilter>(f => filter = f),
                Arg.Any<ListNotesCursor?>(),
                Arg.Do<int>(t => take = t),
                Arg.Any<CancellationToken>())
            .Returns(new List<ListNotesItemDto>());

        await new ListNotesQuery(_currentUser, _noteQueries).ExecuteAsync(
            new ListNotesInputDto(Q: "  Ghi CHÚ   Đầu Tiên ", LabelIds: null, Scope: null, Cursor: null, Limit: 10),
            TestData.Ct);

        Assert.NotNull(filter);
        Assert.Equal("ghi chu dau tien", filter.SearchText);
        Assert.Equal(NoteListScope.Owned, filter.Scope);
        Assert.Equal(11, take);
    }

    [Fact]
    public async Task TamperedCursor_IsValidationError_WithoutQuerying()
    {
        var result = await new ListNotesQuery(_currentUser, _noteQueries).ExecuteAsync(
            new ListNotesInputDto(Q: null, LabelIds: null, Scope: null, Cursor: "rác!!", Limit: null),
            TestData.Ct);

        Assert.Equal(InputErrors.InvalidCursor, result.Error);
        Assert.Empty(_noteQueries.ReceivedCalls());
    }
}

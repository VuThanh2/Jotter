using Jotter.Domain;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class PullChangesQueryTests
{
    private const long PurgedChangeSeq = 100;

    private readonly Guid _userId = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly ISyncQueryService _syncQueries = Substitute.For<ISyncQueryService>();

    public PullChangesQueryTests()
    {
        _currentUser.UserId.Returns(_userId);
        _syncQueries.GetPurgedChangeSeqAsync(Arg.Any<CancellationToken>()).Returns(PurgedChangeSeq);
        _syncQueries.PullAsync(_userId, Arg.Any<long>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(new PullChangesOutputDto([], [], [], [], NextChangeSeq: 150, HasMore: false, FullResyncRequired: false));
    }

    // Tombstone sau mốc since đã bị dọn: đồng bộ theo phần lúc này sẽ làm note đã xoá sống lại trên thiết bị.
    [Fact]
    public async Task CursorOlderThanPurgedTombstones_RequiresFullResync()
    {
        var result = await ExecuteAsync(since: PurgedChangeSeq - 1);

        Assert.True(result.Value.FullResyncRequired);
        await _syncQueries.DidNotReceive().PullAsync(
            Arg.Any<Guid>(), Arg.Any<long>(), Arg.Any<int>(), Arg.Any<CancellationToken>());
    }

    [Theory]
    [InlineData(0)]
    [InlineData(PurgedChangeSeq)]
    public async Task InitialSyncOrCursorAtPurgeBoundary_PullsIncrementally(long since)
    {
        var result = await ExecuteAsync(since);

        Assert.False(result.Value.FullResyncRequired);
        await _syncQueries.Received(1).PullAsync(
            _userId, since, PullChangesQuery.DefaultLimit, Arg.Any<CancellationToken>());
    }

    private Task<Result<PullChangesOutputDto>> ExecuteAsync(long since) =>
        new PullChangesQuery(_currentUser, _syncQueries)
            .ExecuteAsync(new PullChangesInputDto(since, Limit: null), TestData.Ct);
}

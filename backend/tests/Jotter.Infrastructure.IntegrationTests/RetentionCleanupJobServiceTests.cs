using Jotter.Application;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Dọn dẹp xoá vật lý dữ liệu: xoá nhầm thì mất dữ liệu thật, còn quên báo thì thiết bị cũ để note đã xoá sống lại.
public sealed class RetentionCleanupJobServiceTests(PostgresFixture postgres) : DatabaseTest(postgres)
{
    [Fact]
    public async Task PurgesOnlyExpiredTombstones_AndForcesDevicesBehindThePurgeToResync()
    {
        var owner = await Host.SignUpAsync();
        var alive = await Host.CreateNoteAsync(owner);
        var expired = await Host.CreateNoteAsync(owner);
        var staleCursor = (await PullAsync(owner, since: 0)).NextChangeSeq;

        Host.ActAs(owner);
        await Host.RunAsync((DeleteNoteCommand delete) => delete.ExecuteAsync(expired, Ct));
        Host.Clock.Advance(TimeSpan.FromDays(31));

        var recent = await Host.CreateNoteAsync(owner);
        await Host.RunAsync((DeleteNoteCommand delete) => delete.ExecuteAsync(recent, Ct));
        var currentCursor = (await PullAsync(owner, since: 0)).NextChangeSeq;

        await Host.RunJobOnceAsync<RetentionCleanupJobService>();

        var remaining = await Host.WithScopeAsync(services =>
            services.GetRequiredService<AppDbContext>().Notes.Select(n => n.Id).ToListAsync(Ct));

        Assert.Equal(new[] { alive, recent }.Order(), remaining.Order());
        Assert.True((await PullAsync(owner, staleCursor)).FullResyncRequired);
        Assert.False((await PullAsync(owner, currentCursor)).FullResyncRequired);
    }

    private async Task<PullChangesOutputDto> PullAsync(TestAccount account, long since)
    {
        Host.ActAs(account);
        return (await Host.RunAsync((PullChangesQuery pull) =>
            pull.ExecuteAsync(new PullChangesInputDto(since, null), Ct))).Value;
    }
}

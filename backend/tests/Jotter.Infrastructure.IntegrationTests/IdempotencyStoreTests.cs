using Jotter.Application;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Lần ghi nghiệp vụ và bản ghi ProcessedOperation phải commit hoặc rollback cùng nhau: lệch nhau là
// hoặc thực thi trùng khi client gửi lại, hoặc trả về một kết quả chưa từng được lưu.
public sealed class IdempotencyStoreTests(PostgresFixture postgres) : DatabaseTest(postgres)
{
    [Fact]
    public async Task CompletedOperation_PersistsTheWriteAndTheResponseTogether()
    {
        var owner = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);
        var operationId = Guid.NewGuid();
        byte[] body = [1, 2, 3];

        await PinInsideOperationAsync(owner, noteId, operationId, complete: new IdempotentResponse(200, "application/json", body));

        var replay = await FindAsync(owner, operationId);
        Assert.Equal(200, replay!.StatusCode);
        Assert.Equal(body, replay.Body);
        Assert.True(await IsPinnedAsync(noteId));
    }

    [Fact]
    public async Task AbandonedOperation_RollsBackTheWrite_AndRecordsNothing()
    {
        var owner = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);
        var operationId = Guid.NewGuid();

        await PinInsideOperationAsync(owner, noteId, operationId, complete: null);

        Assert.Null(await FindAsync(owner, operationId));
        Assert.False(await IsPinnedAsync(noteId));
    }

    private Task PinInsideOperationAsync(TestAccount owner, Guid noteId, Guid operationId, IdempotentResponse? complete) =>
        Host.WithScopeAsync(async services =>
        {
            Host.ActAs(owner);
            await using var operation = await services.GetRequiredService<IIdempotencyStore>()
                .BeginAsync(owner.UserId, operationId, Ct);

            await services.GetRequiredService<PinNoteCommand>().ExecuteAsync(noteId, new PinNoteInputDto(true), Ct);

            if (complete is not null)
            {
                await operation.CompleteAsync(complete, Ct);
            }
        });

    private Task<IdempotentResponse?> FindAsync(TestAccount owner, Guid operationId) =>
        Host.WithScopeAsync(services =>
            services.GetRequiredService<IIdempotencyStore>().FindAsync(owner.UserId, operationId, Ct));

    private Task<bool> IsPinnedAsync(Guid noteId) =>
        Host.WithScopeAsync(services => services.GetRequiredService<AppDbContext>().Notes
            .Where(n => n.Id == noteId)
            .Select(n => n.IsPinned)
            .SingleAsync(Ct));
}

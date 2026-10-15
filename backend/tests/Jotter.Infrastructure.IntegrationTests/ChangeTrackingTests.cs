using Jotter.Application;
using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// changeSeq là con trỏ duy nhất của đồng bộ; Version là thứ duy nhất chặn ghi đè lẫn nhau khi auto-save.
public sealed class ChangeTrackingTests(PostgresFixture postgres) : DatabaseTest(postgres)
{
    [Fact]
    public async Task EverySyncedChange_GetsAHigherChangeSeq_WhileVersionTracksContentOnly()
    {
        var owner = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);
        var labelId = Guid.CreateVersion7();
        Host.ActAs(owner);
        await Host.RunAsync((CreateLabelCommand create) => create.ExecuteAsync(new CreateLabelInputDto(labelId, "A"), Ct));

        var created = await SnapshotAsync(noteId);
        await Host.RunAsync((UpdateNoteContentCommand update) =>
            update.ExecuteAsync(noteId, new UpdateNoteContentInputDto(1, "Mới", "Mới"), Ct));
        var edited = await SnapshotAsync(noteId);
        await Host.RunAsync((PinNoteCommand pin) => pin.ExecuteAsync(noteId, new PinNoteInputDto(true), Ct));
        var pinned = await SnapshotAsync(noteId);

        // Gắn nhãn chỉ thêm dòng vào bảng liên kết; dòng note vẫn phải nhận changeSeq mới để thiết bị khác biết.
        await Host.RunAsync((SetNoteLabelsCommand set) => set.ExecuteAsync(noteId, new SetNoteLabelsInputDto([labelId]), Ct));
        var labeled = await SnapshotAsync(noteId);

        Assert.True(created.ChangeSeq < edited.ChangeSeq && edited.ChangeSeq < pinned.ChangeSeq);
        Assert.True(pinned.ChangeSeq < labeled.ChangeSeq);
        Assert.Equal([1L, 2L, 2L, 2L], new[] { created.Version, edited.Version, pinned.Version, labeled.Version });
    }

    // Tóm tắt nằm ngoài đồng bộ và realtime: lưu nó không được đổi changeSeq hay Version của note.
    [Fact]
    public async Task SavingASummary_LeavesTheNotesChangeSeqAndVersionUntouched()
    {
        var owner = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);
        var before = await SnapshotAsync(noteId);

        await Host.WithScopeAsync(async services =>
        {
            var note = await services.GetRequiredService<INoteRepository>().GetByIdAsync(noteId, Ct);
            note!.SetSummary("Tóm tắt", Host.Clock.GetUtcNow());
            await services.GetRequiredService<IUnitOfWork>().SaveChangesAsync(Ct);
        });

        Assert.Equal(before, await SnapshotAsync(noteId));
    }

    [Fact]
    public async Task DeletingALabel_GivesEveryNoteThatCarriedItANewChangeSeq()
    {
        var owner = await Host.SignUpAsync();
        var labeled = await Host.CreateNoteAsync(owner);
        var untouched = await Host.CreateNoteAsync(owner);
        var labelId = Guid.CreateVersion7();
        Host.ActAs(owner);
        await Host.RunAsync((CreateLabelCommand create) => create.ExecuteAsync(new CreateLabelInputDto(labelId, "A"), Ct));
        await Host.RunAsync((SetNoteLabelsCommand set) => set.ExecuteAsync(labeled, new SetNoteLabelsInputDto([labelId]), Ct));
        var labeledBefore = await SnapshotAsync(labeled);
        var untouchedBefore = await SnapshotAsync(untouched);

        await Host.RunAsync((DeleteLabelCommand delete) => delete.ExecuteAsync(labelId, Ct));

        Assert.True((await SnapshotAsync(labeled)).ChangeSeq > labeledBefore.ChangeSeq);
        Assert.Equal(untouchedBefore, await SnapshotAsync(untouched));
    }

    // Hai thiết bị cùng sửa từ một version: cả hai qua được bước kiểm baseVersion trong bộ nhớ,
    // nên chỉ concurrency token ở DB mới ngăn được lần ghi sau đè mất lần ghi trước.
    [Fact]
    public async Task TwoWritesBasedOnTheSameVersion_OnlyTheFirstIsSaved()
    {
        var owner = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);

        await using var first = Host.Services.CreateAsyncScope();
        await using var second = Host.Services.CreateAsyncScope();
        var firstNote = await first.ServiceProvider.GetRequiredService<INoteRepository>().GetByIdAsync(noteId, Ct);
        var secondNote = await second.ServiceProvider.GetRequiredService<INoteRepository>().GetByIdAsync(noteId, Ct);
        firstNote!.UpdateContent(1, "Thiết bị A", "A", Host.Clock.GetUtcNow());
        secondNote!.UpdateContent(1, "Thiết bị B", "B", Host.Clock.GetUtcNow());

        await first.ServiceProvider.GetRequiredService<IUnitOfWork>().SaveChangesAsync(Ct);
        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() =>
            second.ServiceProvider.GetRequiredService<IUnitOfWork>().SaveChangesAsync(Ct));

        Assert.Equal("Thiết bị A", await Host.WithScopeAsync(services =>
            services.GetRequiredService<AppDbContext>().Notes.Where(n => n.Id == noteId).Select(n => n.Title).SingleAsync(Ct)));
    }

    private Task<NoteSnapshot> SnapshotAsync(Guid noteId) =>
        Host.WithScopeAsync(services => services.GetRequiredService<AppDbContext>().Notes
            .Where(n => n.Id == noteId)
            .Select(n => new NoteSnapshot(n.ChangeSeq, n.Version))
            .SingleAsync(Ct));

    private sealed record NoteSnapshot(long ChangeSeq, long Version);
}

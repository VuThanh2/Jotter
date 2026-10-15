using Jotter.Application;
using Jotter.Domain;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

public sealed class NoteQueryServiceTests(PostgresFixture postgres) : DatabaseTest(postgres)
{
    // Nội dung note đang khoá không được lọt ra qua bất kỳ đường đọc nào: tìm kiếm, preview hay GET.
    [Fact]
    public async Task LockedNote_IsMatchedByTitleOnly_AndNeverReturnsContent_UntilUnlocked()
    {
        var owner = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner, "Nhật ký", "Mật mã két sắt là 2468");
        await Host.ProtectAndLockAsync(owner, noteId, "1234");
        Host.ActAs(owner);

        var byContent = await SearchAsync("ket sat");
        var byTitle = await SearchAsync("NHAT KY");
        var get = await Host.RunAsync((GetNoteQuery query) => query.ExecuteAsync(noteId, Ct));

        Assert.Empty(byContent);
        Assert.Equal(string.Empty, Assert.Single(byTitle).Preview);
        Assert.Equal(AccessErrors.NoteLocked.Code, get.Error.Code);
        var lockedNote = Assert.IsType<GetNoteOutputDto>(get.Error.Details!["note"]);
        Assert.Null(lockedNote.Content);

        await Host.RunAsync((UnlockNoteCommand unlock) => unlock.ExecuteAsync(noteId, new UnlockNoteInputDto("1234"), Ct));

        Assert.Single(await SearchAsync("ket sat"));
    }

    // Nhãn và ghim là cách tổ chức riêng của chủ sở hữu; người được chia sẻ không được thấy, cũng không lọc theo được.
    [Fact]
    public async Task SharedNotes_NeverExposeTheOwnersLabelsOrPin()
    {
        var owner = await Host.SignUpAsync();
        var recipient = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);
        var labelId = Guid.CreateVersion7();
        Host.ActAs(owner);
        await Host.RunAsync((CreateLabelCommand create) => create.ExecuteAsync(new CreateLabelInputDto(labelId, "Riêng"), Ct));
        await Host.RunAsync((SetNoteLabelsCommand set) => set.ExecuteAsync(noteId, new SetNoteLabelsInputDto([labelId]), Ct));
        await Host.RunAsync((PinNoteCommand pin) => pin.ExecuteAsync(noteId, new PinNoteInputDto(true), Ct));
        await Host.ShareAsync(owner, noteId, recipient, SharePermission.Edit);

        Host.ActAs(recipient);
        var listed = Assert.Single(await ListAsync(new ListNotesInputDto(null, null, NoteListScope.All, null, null)));
        var filteredByOwnersLabel = await ListAsync(new ListNotesInputDto(null, [labelId], NoteListScope.All, null, null));
        var note = (await Host.RunAsync((GetNoteQuery get) => get.ExecuteAsync(noteId, Ct))).Value;

        Assert.Null(listed.LabelIds);
        Assert.Null(listed.IsPinned);
        Assert.Empty(filteredByOwnersLabel);
        Assert.Null(note.LabelIds);
        Assert.Null(note.IsPinned);
        Assert.Equal(NoteAccessLevel.Edit, note.Permission);
    }

    [Fact]
    public async Task CursorPaging_ListsEveryNoteExactlyOnce_WithPinnedNotesFirst()
    {
        var owner = await Host.SignUpAsync();
        var noteIds = new List<Guid>();
        for (var i = 0; i < 7; i++)
        {
            Host.Clock.Advance(TimeSpan.FromSeconds(1));
            noteIds.Add(await Host.CreateNoteAsync(owner, $"Note {i}"));
        }

        Host.ActAs(owner);
        foreach (var pinned in new[] { noteIds[0], noteIds[3] })
        {
            Host.Clock.Advance(TimeSpan.FromSeconds(1));
            await Host.RunAsync((PinNoteCommand pin) => pin.ExecuteAsync(pinned, new PinNoteInputDto(true), Ct));
        }

        var listed = new List<ListNotesItemDto>();
        string? cursor = null;
        do
        {
            var page = (await Host.RunAsync((ListNotesQuery list) =>
                list.ExecuteAsync(new ListNotesInputDto(null, null, null, cursor, 3), Ct))).Value;
            listed.AddRange(page.Items);
            cursor = page.NextCursor;
        }
        while (cursor is not null);

        Assert.Equal(noteIds.Order(), listed.Select(n => n.NoteId).Order());
        Assert.Equal([noteIds[3], noteIds[0]], listed.Take(2).Select(n => n.NoteId));
        Assert.Equal(noteIds[6], listed[2].NoteId);
    }

    private async Task<IReadOnlyList<ListNotesItemDto>> SearchAsync(string text) =>
        await ListAsync(new ListNotesInputDto(text, null, null, null, null));

    private async Task<IReadOnlyList<ListNotesItemDto>> ListAsync(ListNotesInputDto input) =>
        (await Host.RunAsync((ListNotesQuery list) => list.ExecuteAsync(input, Ct))).Value.Items;
}

using Jotter.Application;
using Jotter.Domain;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Lỗi ở đồng bộ không báo lỗi gì cả: dữ liệu đã xoá âm thầm sống lại, hoặc note đã bị thu hồi nằm lại trên máy người khác.
public sealed class SyncQueryServiceTests(PostgresFixture postgres) : DatabaseTest(postgres)
{
    [Fact]
    public async Task Pull_DeliversTombstones_SoDeletionsAndRevocationsReachOfflineDevices()
    {
        var owner = await Host.SignUpAsync();
        var recipient = await Host.SignUpAsync();
        var sharedNote = await Host.CreateNoteAsync(owner);
        var deletedNote = await Host.CreateNoteAsync(owner);
        var shareId = await Host.ShareAsync(owner, sharedNote, recipient, SharePermission.Edit);
        var ownerCursor = (await PullAsync(owner, since: 0)).NextChangeSeq;
        var recipientCursor = (await PullAsync(recipient, since: 0)).NextChangeSeq;

        Host.ActAs(owner);
        await Host.RunAsync((DeleteNoteCommand delete) => delete.ExecuteAsync(deletedNote, Ct));
        await Host.RunAsync((RevokeShareCommand revoke) => revoke.ExecuteAsync(sharedNote, shareId, Ct));

        var ownerChanges = await PullAsync(owner, ownerCursor);
        var recipientChanges = await PullAsync(recipient, recipientCursor);

        Assert.NotNull(Assert.Single(ownerChanges.Notes, n => n.NoteId == deletedNote).DeletedAt);
        Assert.NotNull(Assert.Single(recipientChanges.Shares, s => s.ShareId == shareId).RevokedAt);
        Assert.DoesNotContain(recipientChanges.Notes, n => n.NoteId == sharedNote);
    }

    // Note có changeSeq cũ hơn con trỏ của người nhận vẫn phải về máy họ khi vừa được chia sẻ — kèm tệp đính kèm,
    // nhưng không kèm nhãn/ghim của chủ sở hữu và không kèm nội dung đang bị khoá.
    [Fact]
    public async Task NoteSharedAfterTheCursor_ArrivesWithItsAttachments_ButWithoutOwnerStateOrLockedContent()
    {
        var owner = await Host.SignUpAsync();
        var recipient = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner, "Kế hoạch", "Nội dung kín");
        await PrepareOwnerStateAsync(owner, noteId);

        // Người nhận đã đồng bộ tới sau mọi thay đổi của note (và tệp của nó), nên chỉ grant mới mới đưa được note về.
        await Host.CreateNoteAsync(recipient);
        var recipientCursor = (await PullAsync(recipient, since: 0)).NextChangeSeq;

        await Host.ShareAsync(owner, noteId, recipient, SharePermission.ReadOnly);
        var changes = await PullAsync(recipient, recipientCursor);

        var note = Assert.Single(changes.Notes);
        Assert.Equal(noteId, note.NoteId);
        Assert.True(note.ChangeSeq < recipientCursor);
        Assert.Equal(NoteAccessLevel.ReadOnly, note.Permission);
        Assert.True(note.IsProtected);
        Assert.Null(note.Content);
        Assert.Null(note.SearchContent);
        Assert.Null(note.LabelIds);
        Assert.Null(note.IsPinned);
        Assert.Single(changes.Attachments, a => a.NoteId == noteId);
    }

    [Fact]
    public async Task PagedPull_ReturnsEveryChangeExactlyOnce_WithAStrictlyAdvancingCursor()
    {
        var owner = await Host.SignUpAsync();
        var friend = await Host.SignUpAsync();
        for (var i = 0; i < 5; i++)
        {
            var noteId = await Host.CreateNoteAsync(owner, $"Note {i}");
            await Host.ShareAsync(owner, noteId, friend, SharePermission.ReadOnly);
        }

        await CreateLabelAsync(owner, "A");
        await CreateLabelAsync(owner, "B");

        var everything = await PullAsync(owner, since: 0, limit: PullChangesQuery.MaxLimit);
        var pagedIds = new List<Guid>();
        long cursor = 0;
        PullChangesOutputDto page;
        do
        {
            page = await PullAsync(owner, cursor, limit: 3);
            Assert.True(page.NextChangeSeq > cursor);
            cursor = page.NextChangeSeq;
            pagedIds.AddRange(Ids(page));
        }
        while (page.HasMore);

        Assert.False(everything.HasMore);
        Assert.Equal(Ids(everything).Order(), pagedIds.Order());
    }

    private async Task PrepareOwnerStateAsync(TestAccount owner, Guid noteId)
    {
        var labelId = await CreateLabelAsync(owner, "Riêng tư");
        Host.ActAs(owner);
        await Host.RunAsync((SetNoteLabelsCommand set) =>
            set.ExecuteAsync(noteId, new SetNoteLabelsInputDto([labelId]), Ct));
        await Host.RunAsync((PinNoteCommand pin) => pin.ExecuteAsync(noteId, new PinNoteInputDto(true), Ct));
        await Host.RunAsync((UploadAttachmentsCommand upload) =>
            upload.ExecuteAsync(noteId, new UploadAttachmentsInputDto([Upload("a.png", Png)]), Ct));

        // Chia sẻ note đang bảo vệ đòi chủ sở hữu mở khoá trước.
        await Host.ProtectAndLockAsync(owner, noteId, "1234");
        await Host.RunAsync((UnlockNoteCommand unlock) =>
            unlock.ExecuteAsync(noteId, new UnlockNoteInputDto("1234"), Ct));
    }

    private async Task<Guid> CreateLabelAsync(TestAccount owner, string name)
    {
        Host.ActAs(owner);
        var labelId = Guid.CreateVersion7();
        await Host.RunAsync((CreateLabelCommand create) =>
            create.ExecuteAsync(new CreateLabelInputDto(labelId, name), Ct));
        return labelId;
    }

    private async Task<PullChangesOutputDto> PullAsync(TestAccount account, long since, int? limit = null)
    {
        Host.ActAs(account);
        var result = await Host.RunAsync((PullChangesQuery pull) =>
            pull.ExecuteAsync(new PullChangesInputDto(since, limit), Ct));
        return result.Value;
    }

    private static IEnumerable<Guid> Ids(PullChangesOutputDto changes) =>
        changes.Notes.Select(n => n.NoteId)
            .Concat(changes.Labels.Select(l => l.LabelId))
            .Concat(changes.Shares.Select(s => s.ShareId))
            .Concat(changes.Attachments.Select(a => a.AttachmentId));
}

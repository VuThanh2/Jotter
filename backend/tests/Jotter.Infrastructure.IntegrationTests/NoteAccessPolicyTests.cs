using Jotter.Application;
using Jotter.Domain;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Policy là điểm DUY NHẤT quyết định quyền cho REST, WebSocket, RAG và sync: sai ở đây là rò rỉ ở cả bốn nơi.
public sealed class NoteAccessPolicyTests(PostgresFixture postgres) : DatabaseTest(postgres)
{
    [Fact]
    public async Task AccessLevel_FollowsOwnershipAndActiveGrants_AndRevokingTakesEffectImmediately()
    {
        var owner = await Host.SignUpAsync();
        var editor = await Host.SignUpAsync();
        var reader = await Host.SignUpAsync();
        var stranger = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);
        await Host.ShareAsync(owner, noteId, editor, SharePermission.Edit);
        var readerShareId = await Host.ShareAsync(owner, noteId, reader, SharePermission.ReadOnly);

        Assert.Equal(NoteAccessLevel.Owner, (await AccessAsync(owner, noteId)).Level);
        Assert.Equal(NoteAccessLevel.Edit, (await AccessAsync(editor, noteId)).Level);
        Assert.Equal(NoteAccessLevel.ReadOnly, (await AccessAsync(reader, noteId)).Level);
        Assert.Equal(NoteAccess.None, await AccessAsync(stranger, noteId));

        Host.ActAs(owner);
        await Host.RunAsync((RevokeShareCommand revoke) => revoke.ExecuteAsync(noteId, readerShareId, Ct));

        Assert.Equal(NoteAccess.None, await AccessAsync(reader, noteId));
    }

    [Fact]
    public async Task DeletedNote_IsInvisibleToOwnerAndRecipients()
    {
        var owner = await Host.SignUpAsync();
        var recipient = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);
        await Host.ShareAsync(owner, noteId, recipient, SharePermission.Edit);

        Host.ActAs(owner);
        await Host.RunAsync((DeleteNoteCommand delete) => delete.ExecuteAsync(noteId, Ct));

        Assert.Equal(NoteAccess.None, await AccessAsync(owner, noteId));
        Assert.Equal(NoteAccess.None, await AccessAsync(recipient, noteId));
    }

    // Phiên mở khoá là trạng thái ở server và có hạn: hết hạn thì note khoá lại dù client vẫn "nhớ" đã mở.
    [Fact]
    public async Task ProtectedNote_IsUnlockedOnlyWhileTheCallersOwnUnlockSessionLasts()
    {
        var owner = await Host.SignUpAsync();
        var recipient = await Host.SignUpAsync();
        var noteId = await Host.CreateNoteAsync(owner);
        await Host.ShareAsync(owner, noteId, recipient, SharePermission.Edit);
        await Host.ProtectAndLockAsync(owner, noteId, "1234");

        Host.ActAs(owner);
        await Host.RunAsync((UnlockNoteCommand unlock) => unlock.ExecuteAsync(noteId, new UnlockNoteInputDto("1234"), Ct));

        Assert.False((await AccessAsync(owner, noteId)).IsLocked);
        Assert.True((await AccessAsync(recipient, noteId)).IsLocked);

        Host.Clock.Advance(NoteUnlockSession.Lifetime + TimeSpan.FromSeconds(1));

        Assert.True((await AccessAsync(owner, noteId)).IsLocked);
    }

    // Phạm vi truy hồi của hỏi đáp AI: của mình hoặc được chia sẻ còn hiệu lực, trừ note đã xoá và note đang khoá.
    [Fact]
    public async Task ContentReadableScope_ExcludesDeletedRevokedAndLockedNotes()
    {
        var user = await Host.SignUpAsync();
        var other = await Host.SignUpAsync();
        var own = await Host.CreateNoteAsync(user);
        var ownDeleted = await Host.CreateNoteAsync(user);
        var ownLocked = await Host.CreateNoteAsync(user);
        var sharedToUser = await Host.CreateNoteAsync(other);
        var revokedFromUser = await Host.CreateNoteAsync(other);
        await Host.CreateNoteAsync(other);

        await Host.ShareAsync(other, sharedToUser, user, SharePermission.ReadOnly);
        var revokedShareId = await Host.ShareAsync(other, revokedFromUser, user, SharePermission.ReadOnly);
        Host.ActAs(other);
        await Host.RunAsync((RevokeShareCommand revoke) => revoke.ExecuteAsync(revokedFromUser, revokedShareId, Ct));

        await Host.ProtectAndLockAsync(user, ownLocked, "1234");
        Host.ActAs(user);
        await Host.RunAsync((DeleteNoteCommand delete) => delete.ExecuteAsync(ownDeleted, Ct));

        var readable = await Host.WithScopeAsync(services =>
            services.GetRequiredService<INoteAccessPolicy>().ListContentReadableNoteIdsAsync(user.UserId, Ct));

        Assert.Equal(new[] { own, sharedToUser }.Order(), readable.Order());
    }

    private Task<NoteAccess> AccessAsync(TestAccount account, Guid noteId) =>
        Host.WithScopeAsync(services =>
            services.GetRequiredService<INoteAccessPolicy>().GetAccessAsync(account.UserId, noteId, Ct));
}

using Jotter.Application;
using Jotter.Domain;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Quyền chỉ được kiểm lúc join kênh, nên thu hồi/hạ quyền phải chủ động đẩy xuống socket. Trong request idempotent,
// tín hiệu chỉ được phát sau khi transaction commit — rollback thì không được phát gì và không được đá ai.
public sealed class RealtimeSignalTests(PostgresFixture postgres) : DatabaseTest(postgres)
{
    private NoteChannelRegistry Registry => Host.Services.GetRequiredService<NoteChannelRegistry>();

    [Fact]
    public async Task RevokeInsideAnIdempotentRequest_KicksTheRecipientOnlyAfterCommit()
    {
        var (owner, recipient, noteId, shareId) = await SharedNoteAsync();
        var (socket, connection) = Join(recipient, noteId);

        await Host.WithScopeAsync(async services =>
        {
            Host.ActAs(owner);
            await using var operation = await services.GetRequiredService<IIdempotencyStore>()
                .BeginAsync(owner.UserId, Guid.NewGuid(), Ct);

            await services.GetRequiredService<RevokeShareCommand>().ExecuteAsync(noteId, shareId, Ct);

            Assert.Empty(socket.Sent);
            Assert.Contains(connection, Registry.Members(noteId));

            await operation.CompleteAsync(new IdempotentResponse(204, null, []), Ct);
        });

        Assert.Contains(socket.Sent, message => message.Contains("\"accessRevoked\""));
        Assert.DoesNotContain(connection, Registry.Members(noteId));
    }

    [Fact]
    public async Task RolledBackRequest_SendsNothing_AndRevokesNothing()
    {
        var (owner, recipient, noteId, shareId) = await SharedNoteAsync();
        var (socket, connection) = Join(recipient, noteId);

        await Host.WithScopeAsync(async services =>
        {
            Host.ActAs(owner);
            await using var operation = await services.GetRequiredService<IIdempotencyStore>()
                .BeginAsync(owner.UserId, Guid.NewGuid(), Ct);

            await services.GetRequiredService<RevokeShareCommand>().ExecuteAsync(noteId, shareId, Ct);
        });

        var access = await Host.WithScopeAsync(services =>
            services.GetRequiredService<INoteAccessPolicy>().GetAccessAsync(recipient.UserId, noteId, Ct));

        Assert.Empty(socket.Sent);
        Assert.Contains(connection, Registry.Members(noteId));
        Assert.Equal(NoteAccessLevel.Edit, access.Level);
    }

    [Fact]
    public async Task PermissionDowngrade_IsPushedOnlyToThatRecipient()
    {
        var (owner, recipient, noteId, shareId) = await SharedNoteAsync();
        var bystander = await Host.SignUpAsync();
        await Host.ShareAsync(owner, noteId, bystander, SharePermission.Edit);
        var (recipientSocket, _) = Join(recipient, noteId);
        var (bystanderSocket, _) = Join(bystander, noteId);
        var (ownerSocket, _) = Join(owner, noteId);

        Host.ActAs(owner);
        await Host.RunAsync((ChangeSharePermissionCommand change) => change.ExecuteAsync(
            noteId,
            shareId,
            new ChangeSharePermissionInputDto(SharePermission.ReadOnly),
            Ct));

        var message = Assert.Single(recipientSocket.Sent);
        Assert.Contains("\"permissionChanged\"", message);
        Assert.Contains("\"ReadOnly\"", message);
        Assert.Empty(bystanderSocket.Sent);
        Assert.Empty(ownerSocket.Sent);
    }

    // Kênh chỉ mang tín hiệu: version mới và tên người sửa, không bao giờ mang nội dung note.
    [Fact]
    public async Task ContentUpdate_SignalsEveryoneInTheNote_WithoutTheContent()
    {
        var (owner, recipient, noteId, _) = await SharedNoteAsync(editorName: "Bình");
        var (ownerSocket, _) = Join(owner, noteId);
        var (editorSocket, _) = Join(recipient, noteId);

        Host.ActAs(recipient);
        await Host.RunAsync((UpdateNoteContentCommand update) =>
            update.ExecuteAsync(noteId, new UpdateNoteContentInputDto(1, "Tiêu đề", "Bí mật mới"), Ct));

        foreach (var socket in new[] { ownerSocket, editorSocket })
        {
            var message = Assert.Single(socket.Sent);
            Assert.Contains("\"noteChanged\"", message);
            Assert.Contains("\"version\":2", message);
            Assert.Contains("\"by\":\"Bình\"", message);
            Assert.DoesNotContain("Bí mật mới", message);
        }
    }

    private async Task<(TestAccount Owner, TestAccount Recipient, Guid NoteId, Guid ShareId)> SharedNoteAsync(
        string editorName = "Người nhận")
    {
        var owner = await Host.SignUpAsync("Chủ note");
        var recipient = await Host.SignUpAsync(editorName);
        var noteId = await Host.CreateNoteAsync(owner);
        var shareId = await Host.ShareAsync(owner, noteId, recipient, SharePermission.Edit);

        return (owner, recipient, noteId, shareId);
    }

    private (RecordingWebSocket Socket, RealtimeConnection Connection) Join(TestAccount account, Guid noteId)
    {
        var socket = new RecordingWebSocket();
        var connection = new RealtimeConnection(socket, account.UserId, account.Email);
        Registry.Join(noteId, connection);
        return (socket, connection);
    }
}

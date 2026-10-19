using System.Net;
using Xunit;
using static Jotter.Api.IntegrationTests.ApiClientExtensions;

namespace Jotter.Api.IntegrationTests;

public sealed class IdempotencyTests(ApiFixture api)
{
    // Request tới nơi nhưng response rớt giữa đường: outbox gửi lại đúng opId. Dùng thao tác tạo note vì nếu filter
    // không chặn, lần gửi lại chắc chắn dính 409 NoteIdAlreadyExists (Domain không tự bỏ qua như khi ghi lại cùng nội dung).
    [Fact]
    public async Task RetryingAWriteWithTheSameKey_ReplaysTheFirstResponseInsteadOfExecutingAgain()
    {
        using var client = await api.CreateUserClientAsync();
        var key = Guid.NewGuid();
        var note = new { noteId = Guid.CreateVersion7(), title = "Outbox", content = "Gửi hai lần" };

        using var first = await client.SendJsonAsync(HttpMethod.Post, "/api/notes", note, key);
        using var retry = await client.SendJsonAsync(HttpMethod.Post, "/api/notes", note, key);

        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        Assert.False(first.Headers.Contains(ReplayHeader));

        Assert.Equal(HttpStatusCode.Created, retry.StatusCode);
        Assert.Equal("true", Assert.Single(retry.Headers.GetValues(ReplayHeader)));
        Assert.Equal(await first.Content.ReadAsStringAsync(Ct), await retry.Content.ReadAsStringAsync(Ct));
    }

    // Lỗi không được đóng băng thành response vĩnh viễn: gửi lại cùng opId sau khi đã mở khoá phải được thực thi thật,
    // nếu không thao tác trong outbox sẽ kẹt ở 423 mãi mãi.
    [Fact]
    public async Task AFailedWrite_IsNotRecorded_SoTheSameKeySucceedsOnceTheCauseIsGone()
    {
        using var client = await api.CreateUserClientAsync();
        var noteId = await client.CreateProtectedNoteAsync();
        var key = Guid.NewGuid();
        var edit = new { baseVersion = 1, title = "Note kiểm thử", content = "Sửa khi đang khoá" };

        using var whileLocked = await client.SendJsonAsync(HttpMethod.Put, $"/api/notes/{noteId}", edit, key);
        await whileLocked.ReadProblemAsync(HttpStatusCode.Locked, "NoteLocked");

        using var unlock = await client.SendJsonAsync(
            HttpMethod.Post,
            $"/api/notes/{noteId}/unlock",
            new { password = NotePassword });
        Assert.Equal(HttpStatusCode.OK, unlock.StatusCode);

        using var retry = await client.SendJsonAsync(HttpMethod.Put, $"/api/notes/{noteId}", edit, key);

        Assert.Equal(HttpStatusCode.OK, retry.StatusCode);
        Assert.False(retry.Headers.Contains(ReplayHeader));
        Assert.Equal(2, (await retry.ReadJsonAsync()).GetProperty("version").GetInt64());
    }

    // opId do client sinh nên hai người có thể trùng key: không bao giờ được trả response (và dữ liệu) của người này
    // cho người kia.
    [Fact]
    public async Task Keys_AreScopedPerUser()
    {
        using var alice = await api.CreateUserClientAsync();
        using var bob = await api.CreateUserClientAsync();
        var sharedKey = Guid.NewGuid();
        var bobsNoteId = Guid.CreateVersion7();

        using var alicesResponse = await alice.SendJsonAsync(
            HttpMethod.Post,
            "/api/notes",
            new { noteId = Guid.CreateVersion7(), title = "Của Alice", content = "Riêng tư" },
            sharedKey);
        using var bobsResponse = await bob.SendJsonAsync(
            HttpMethod.Post,
            "/api/notes",
            new { noteId = bobsNoteId, title = "Của Bob", content = "Riêng tư" },
            sharedKey);

        Assert.Equal(HttpStatusCode.Created, alicesResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Created, bobsResponse.StatusCode);
        Assert.False(bobsResponse.Headers.Contains(ReplayHeader));
        Assert.Equal(bobsNoteId, (await bobsResponse.ReadJsonAsync()).GetProperty("noteId").GetGuid());
    }
}

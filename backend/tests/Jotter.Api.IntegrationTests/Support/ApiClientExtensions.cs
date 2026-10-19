using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Xunit;

namespace Jotter.Api.IntegrationTests;

internal static class ApiClientExtensions
{
    public const string AccountPassword = "Passw0rd!";
    public const string NotePassword = "1234";

    // Viết cứng, không lấy từ hằng của Api: tên header là hợp đồng với client, đổi trong code chính phải làm test đỏ.
    public const string IdempotencyKeyHeader = "Idempotency-Key";
    public const string ReplayHeader = "Idempotent-Replay";

    public static CancellationToken Ct => TestContext.Current.CancellationToken;

    public static async Task<HttpClient> CreateUserClientAsync(this ApiFixture api)
    {
        var client = api.CreateClient();
        using var response = await client.PostAsJsonAsync(
            "/api/auth/register",
            new
            {
                email = $"{Guid.NewGuid():N}@jotter.test",
                displayName = "Người kiểm thử",
                password = AccountPassword,
                confirmPassword = AccountPassword
            },
            Ct);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var accessToken = (await response.ReadJsonAsync()).GetProperty("accessToken").GetString();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        return client;
    }

    public static async Task<Guid> CreateNoteAsync(this HttpClient client, string content = "Nội dung")
    {
        var noteId = Guid.CreateVersion7();
        using var response = await client.SendJsonAsync(
            HttpMethod.Post,
            "/api/notes",
            new { noteId, title = "Note kiểm thử", content });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return noteId;
    }

    // Bật bảo vệ không tự mở khoá cho chủ note, nên note trả về đang ở trạng thái khoá.
    public static async Task<Guid> CreateProtectedNoteAsync(this HttpClient client, string content = "Nội dung")
    {
        var noteId = await client.CreateNoteAsync(content);
        using var response = await client.SendJsonAsync(
            HttpMethod.Post,
            $"/api/notes/{noteId}/protection",
            new { password = NotePassword, confirmPassword = NotePassword });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return noteId;
    }

    public static async Task<HttpResponseMessage> SendJsonAsync(
        this HttpClient client,
        HttpMethod method,
        string path,
        object body,
        Guid? idempotencyKey = null)
    {
        using var request = new HttpRequestMessage(method, path) { Content = JsonContent.Create(body) };
        if (idempotencyKey is { } key)
        {
            request.Headers.Add(IdempotencyKeyHeader, key.ToString());
        }

        return await client.SendAsync(request, Ct);
    }

    public static async Task<JsonElement> ReadJsonAsync(this HttpResponseMessage response) =>
        JsonSerializer.Deserialize<JsonElement>(await response.Content.ReadAsStringAsync(Ct));

    // Mọi lỗi phải cùng một hình dạng: client switch theo "code", báo lỗi kèm "traceId".
    public static async Task<JsonElement> ReadProblemAsync(
        this HttpResponseMessage response,
        HttpStatusCode expectedStatus,
        string expectedCode)
    {
        Assert.Equal(expectedStatus, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);

        var problem = await response.ReadJsonAsync();
        Assert.Equal(expectedCode, problem.GetProperty("code").GetString());
        Assert.Equal((int)expectedStatus, problem.GetProperty("status").GetInt32());
        Assert.False(string.IsNullOrEmpty(problem.GetProperty("traceId").GetString()));

        return problem;
    }
}

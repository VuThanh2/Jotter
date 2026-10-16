using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using Xunit;
using static Jotter.Api.IntegrationTests.ApiClientExtensions;

namespace Jotter.Api.IntegrationTests;

// Hợp đồng mà client Flutter dựa vào: hình dạng lỗi, dữ liệu kèm theo lỗi, và cách serialize enum.
public sealed class ContractTests(ApiFixture api)
{
    private const string Json = "application/json";
    private const string MissingNote = "0199f2a0-0000-7000-8000-000000000000";
    private const string Multipart = "multipart/form-data; boundary=jotter";
    private const string MultipartWithoutFiles =
        "--jotter\r\nContent-Disposition: form-data; name=\"other\"\r\n\r\nx\r\n--jotter--\r\n";

    // Mỗi dòng đi qua một nhánh sinh lỗi khác nhau của pipeline — JwtBearer, model binding, ValidationFilter, validator
    // gọi tường minh, Result của use case, lỗi rỗng của MVC, IdempotencyFilter — và tất cả phải ra cùng một hình dạng.
    // expectedField có dạng "trường" hoặc "trường:mã lỗi của trường".
    [Theory]
    [InlineData(false, "GET", "/api/me", null, null, null, 401, "Unauthorized", null)]
    [InlineData(false, "POST", "/api/auth/login", "{\"email\":", Json, null, 400, "ValidationError", null)]
    [InlineData(false, "POST", "/api/auth/login", "null", Json, null, 400, "ValidationError", "")]
    [InlineData(false, "POST", "/api/auth/register",
        "{\"email\":\"a@jotter.test\",\"displayName\":\"A\",\"password\":\"Passw0rd!\",\"confirmPassword\":\"khác\"}",
        Json, null, 400, "ValidationError", "confirmPassword:PasswordMismatch")]
    [InlineData(true, "POST", $"/api/notes/{MissingNote}/shares", "{\"recipients\":[null]}", Json, null,
        400, "ValidationError", "recipients[0]")]
    [InlineData(true, "POST", "/api/me/avatar", MultipartWithoutFiles, Multipart, null,
        400, "ValidationError", "file:Required")]
    [InlineData(true, "POST", $"/api/notes/{MissingNote}/attachments", MultipartWithoutFiles, Multipart, null,
        400, "ValidationError", "files")]
    [InlineData(true, "POST", "/api/notes", "{\"noteId\":\"" + MissingNote + "\",\"content\":\"x\"}", Json, "not-a-uuid",
        400, "InvalidIdempotencyKey", null)]
    [InlineData(true, "GET", $"/api/notes/{MissingNote}", null, null, null, 404, "NoteNotFound", null)]
    [InlineData(true, "PUT", $"/api/notes/{MissingNote}/pin", null, null, null, 415, "UnsupportedContentType", null)]
    [InlineData(true, "PATCH", "/api/me", null, null, null, 405, "MethodNotAllowed", null)]
    public async Task EveryErrorPath_ReturnsTheSameProblemShape(
        bool authenticated,
        string method,
        string path,
        string? body,
        string? contentType,
        string? idempotencyKey,
        int expectedStatus,
        string expectedCode,
        string? expectedField)
    {
        using var client = authenticated ? await api.CreateUserClientAsync() : api.CreateClient();
        using var request = new HttpRequestMessage(new HttpMethod(method), path);
        if (body is not null)
        {
            request.Content = new StringContent(body, MediaTypeHeaderValue.Parse(contentType!));
        }

        if (idempotencyKey is not null)
        {
            request.Headers.Add(IdempotencyKeyHeader, idempotencyKey);
        }

        using var response = await client.SendAsync(request, Ct);
        var problem = await response.ReadProblemAsync((HttpStatusCode)expectedStatus, expectedCode);

        if (expectedField is not null)
        {
            var (field, fieldCode) = expectedField.Split(':') is [var name, var code] ? (name, code) : (expectedField, null);
            var fieldErrors = problem.GetProperty("errors").GetProperty(field);

            if (fieldCode is not null)
            {
                Assert.Contains(fieldErrors.EnumerateArray(), error => error.GetProperty("code").GetString() == fieldCode);
            }
        }
    }

    // 409 phải mang sẵn bản server để client tách nội dung của mình thành Conflict Copy mà không phải gọi thêm.
    [Fact]
    public async Task StaleBaseVersion_Returns409CarryingTheServerNote()
    {
        using var client = await api.CreateUserClientAsync();
        var noteId = await client.CreateNoteAsync();

        using var saved = await client.SendJsonAsync(
            HttpMethod.Put,
            $"/api/notes/{noteId}",
            new { baseVersion = 1, title = "Note kiểm thử", content = "Bản đã lên server" });
        Assert.Equal(HttpStatusCode.OK, saved.StatusCode);

        using var stale = await client.SendJsonAsync(
            HttpMethod.Put,
            $"/api/notes/{noteId}",
            new { baseVersion = 1, title = "Note kiểm thử", content = "Bản sửa ngoại tuyến" });
        var problem = await stale.ReadProblemAsync(HttpStatusCode.Conflict, "VersionConflict");

        var serverNote = problem.GetProperty("serverNote");
        Assert.Equal(2, serverNote.GetProperty("version").GetInt64());
        Assert.Equal("Bản đã lên server", serverNote.GetProperty("content").GetString());
    }

    // Nội dung note đang khoá không bao giờ được rời server; 423 chỉ kèm metadata để client hiện màn hình mở khoá.
    [Fact]
    public async Task ReadingALockedNote_Returns423WithMetadataButNeverTheContent()
    {
        const string secret = "Mật khẩu ngân hàng 0000";
        using var client = await api.CreateUserClientAsync();
        var noteId = await client.CreateProtectedNoteAsync(secret);

        using var response = await client.GetAsync($"/api/notes/{noteId}", Ct);
        var problem = await response.ReadProblemAsync(HttpStatusCode.Locked, "NoteLocked");

        var note = problem.GetProperty("note");
        Assert.Equal(noteId, note.GetProperty("noteId").GetGuid());
        Assert.True(note.GetProperty("isProtected").GetBoolean());
        Assert.Equal(JsonValueKind.Null, note.GetProperty("content").ValueKind);
        Assert.DoesNotContain(secret, problem.GetRawText());
    }

    // Client Flutter so khớp enum theo chuỗi ("Dark"); số nguyên phải bị từ chối thay vì âm thầm nhận giá trị lạ.
    [Fact]
    public async Task Enums_TravelAsStrings_AndIntegersAreRejected()
    {
        using var client = await api.CreateUserClientAsync();

        using var asString = await client.SendJsonAsync(
            HttpMethod.Put,
            "/api/me/preferences",
            new { noteFontSize = 16, defaultNoteColor = "#FFF8E1", themeMode = "Dark", listViewMode = "List" });
        using var asInteger = await client.SendJsonAsync(
            HttpMethod.Put,
            "/api/me/preferences",
            new { noteFontSize = 16, defaultNoteColor = "#FFF8E1", themeMode = 1, listViewMode = "List" });

        Assert.Equal(HttpStatusCode.OK, asString.StatusCode);
        var preferences = await asString.ReadJsonAsync();
        Assert.Equal("Dark", preferences.GetProperty("themeMode").GetString());
        Assert.Equal("List", preferences.GetProperty("listViewMode").GetString());

        await asInteger.ReadProblemAsync(HttpStatusCode.BadRequest, "ValidationError");
    }
}

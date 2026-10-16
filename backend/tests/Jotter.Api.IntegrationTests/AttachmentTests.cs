using System.Net;
using System.Net.Http.Headers;
using System.Text;
using Xunit;
using static Jotter.Api.IntegrationTests.ApiClientExtensions;

namespace Jotter.Api.IntegrationTests;

public sealed class AttachmentTests(ApiFixture api)
{
    private static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D];

    // Hợp đồng multipart với client (trường "files", nhiều tệp một lần) và tải về đúng từng byte, đúng tên gốc —
    // đoạn chuyển IFormFile sang DTO của Application là code của Api, không tầng nào khác kiểm.
    [Fact]
    public async Task UploadedFiles_AreDownloadedBackByteForByteWithTheirOriginalName()
    {
        using var client = await api.CreateUserClientAsync();
        var noteId = await client.CreateNoteAsync();

        using var form = new MultipartFormDataContent
        {
            { new ByteArrayContent(Encoding.UTF8.GetBytes("Danh sách việc cần làm")), "files", "viec-can-lam.txt" },
            { new ByteArrayContent(Png), "files", "so-do-kien-truc.png" }
        };
        using var upload = await client.PostAsync($"/api/notes/{noteId}/attachments", form, Ct);

        Assert.Equal(HttpStatusCode.Created, upload.StatusCode);
        var items = (await upload.ReadJsonAsync()).GetProperty("items").EnumerateArray().ToList();
        Assert.Equal(2, items.Count);
        var image = Assert.Single(items, item => item.GetProperty("fileName").GetString() == "so-do-kien-truc.png");

        using var download = await client.GetAsync(
            $"/api/attachments/{image.GetProperty("attachmentId").GetGuid()}/content",
            Ct);

        Assert.Equal(HttpStatusCode.OK, download.StatusCode);
        Assert.Equal("image/png", download.Content.Headers.ContentType?.MediaType);
        Assert.Equal("attachment", download.Content.Headers.ContentDisposition?.DispositionType);
        Assert.Equal("so-do-kien-truc.png", FileNameOf(download.Content.Headers.ContentDisposition!));
        Assert.Equal(Png, await download.Content.ReadAsByteArrayAsync(Ct));
    }

    private static string? FileNameOf(ContentDispositionHeaderValue disposition) =>
        disposition.FileNameStar ?? disposition.FileName?.Trim('"');
}

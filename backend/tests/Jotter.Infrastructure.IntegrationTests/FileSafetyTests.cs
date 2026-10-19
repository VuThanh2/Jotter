using System.Text;
using Microsoft.Extensions.Options;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Hai hàng rào an ninh của phần tệp: không thoát được khỏi thư mục lưu trữ, và kiểu tệp chỉ đến từ nội dung thật.
public sealed class FileSafetyTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "jotter-tests", Guid.NewGuid().ToString("N"));
    private readonly MagicBytesFileTypeDetector _detector = new();

    [Theory]
    [InlineData("../outside")]
    [InlineData("attachments/../../outside")]
    [InlineData(@"attachments\..\..\outside")]
    [InlineData("/etc/passwd")]
    [InlineData("C:/Windows/win.ini")]
    [InlineData("attachments")]
    public async Task KeysOutsideTheServerGeneratedFormat_AreRejectedBeforeTouchingTheDisk(string storageKey)
    {
        var storage = new LocalVolumeFileStorage(Options.Create(new StorageOptions { RootPath = _root }));

        await Assert.ThrowsAsync<ArgumentException>(() =>
            storage.SaveAsync(storageKey, new MemoryStream(Png), Ct));
        await Assert.ThrowsAsync<ArgumentException>(() => storage.OpenReadAsync(storageKey, Ct));
        await Assert.ThrowsAsync<ArgumentException>(() => storage.DeleteAsync(storageKey, Ct));
    }

    public static TheoryData<byte[], string> KnownSignatures => new()
    {
        { Png, "image/png" },
        { Jpeg, "image/jpeg" },
        { "RIFF\0\0\0\0WEBPVP8 "u8.ToArray(), "image/webp" },
        { "%PDF-1.7\n"u8.ToArray(), "application/pdf" },
        { "\0\0\0\u0018ftypisom"u8.ToArray(), "video/mp4" },
        { WindowsExecutable, "application/x-msdownload" },
        { [0x7F, 0x45, 0x4C, 0x46, 0x02, 0x01], "application/x-elf" }
    };

    // Stream phải được trả về đúng vị trí cũ: Command đọc magic bytes rồi mới ghi tệp từ chính stream đó.
    [Theory]
    [MemberData(nameof(KnownSignatures))]
    public async Task Detector_IdentifiesTheTypeFromContent_AndRewindsTheStream(byte[] content, string expectedMimeType)
    {
        using var stream = new MemoryStream(content);

        var mimeType = await _detector.DetectMimeTypeAsync(stream, Ct);

        Assert.Equal(expectedMimeType, mimeType);
        Assert.Equal(0, stream.Position);
    }

    // Không đoán kiểu cho văn bản: một tệp HTML/SVG được phục vụ như trang web là đường cho XSS.
    [Theory]
    [InlineData("<svg xmlns=\"http://www.w3.org/2000/svg\"><script>alert(1)</script></svg>")]
    [InlineData("<!doctype html><html><body>hi</body></html>")]
    [InlineData("Chỉ là văn bản thường.")]
    public async Task Detector_NeverAssignsATypeToTextOrMarkup(string text)
    {
        var mimeType = await _detector.DetectMimeTypeAsync(new MemoryStream(Encoding.UTF8.GetBytes(text)), Ct);

        Assert.Null(mimeType);
    }

    public void Dispose()
    {
        if (Directory.Exists(_root))
        {
            Directory.Delete(_root, recursive: true);
        }
    }
}

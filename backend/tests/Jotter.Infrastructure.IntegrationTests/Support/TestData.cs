using Jotter.Application;
using Xunit;

namespace Jotter.Infrastructure.IntegrationTests;

internal static class TestData
{
    // Thoả chính sách mật khẩu mặc định của Identity.
    public const string Password = "Passw0rd!";

    public static readonly byte[] Png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D];

    public static readonly byte[] Jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46];

    public static readonly byte[] WindowsExecutable = [0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00];

    public static CancellationToken Ct => TestContext.Current.CancellationToken;

    public static FileUploadDto Upload(string fileName, byte[] bytes) =>
        new(fileName, bytes.Length, new MemoryStream(bytes));
}

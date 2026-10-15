using System.Text;
using Jotter.Application;

namespace Jotter.Infrastructure;

// Chỉ dựa vào chữ ký nhị phân ở đầu tệp. Văn bản thuần, HTML, SVG không có chữ ký nên trả null (application/octet-stream):
// không bao giờ đoán ra một kiểu mà trình duyệt có thể thực thi khi mở trực tiếp.
public sealed class MagicBytesFileTypeDetector : IFileTypeDetector
{
    // Đủ để nhìn thấy tên các entry đầu tiên của tệp Office (zip) bên cạnh các chữ ký nằm ở vài byte đầu.
    private const int HeaderLength = 8 * 1024;

    private static readonly (byte[] Signature, string MimeType)[] Signatures =
    [
        ([0xFF, 0xD8, 0xFF], "image/jpeg"),
        ([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], "image/png"),
        ("GIF87a"u8.ToArray(), "image/gif"),
        ("GIF89a"u8.ToArray(), "image/gif"),
        ([0x49, 0x49, 0x2A, 0x00], "image/tiff"),
        ([0x4D, 0x4D, 0x00, 0x2A], "image/tiff"),
        ("%PDF-"u8.ToArray(), "application/pdf"),
        ("{\\rtf"u8.ToArray(), "application/rtf"),
        ([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1], "application/x-ole-storage"),
        ([0x1F, 0x8B], "application/gzip"),
        ([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C], "application/x-7z-compressed"),
        ("Rar!\u001A\u0007"u8.ToArray(), "application/vnd.rar"),
        ("ID3"u8.ToArray(), "audio/mpeg"),
        ([0xFF, 0xFB], "audio/mpeg"),
        ([0xFF, 0xF3], "audio/mpeg"),
        ([0xFF, 0xF2], "audio/mpeg"),
        ("OggS"u8.ToArray(), "audio/ogg"),
        ("fLaC"u8.ToArray(), "audio/flac"),
        ([0x1A, 0x45, 0xDF, 0xA3], "video/webm"),
        // Tệp thực thi: nhận diện để UploadAttachmentsCommand chặn.
        ("MZ"u8.ToArray(), "application/x-msdownload"),
        ([0x7F, 0x45, 0x4C, 0x46], "application/x-elf"),
        ([0xFE, 0xED, 0xFA, 0xCE], "application/x-mach-binary"),
        ([0xFE, 0xED, 0xFA, 0xCF], "application/x-mach-binary"),
        ([0xCE, 0xFA, 0xED, 0xFE], "application/x-mach-binary"),
        ([0xCF, 0xFA, 0xED, 0xFE], "application/x-mach-binary"),
        ([0xCA, 0xFE, 0xBA, 0xBE], "application/x-mach-binary")
    ];

    private static readonly Dictionary<string, string> IsoMediaBrands = new(StringComparer.Ordinal)
    {
        ["heic"] = "image/heic",
        ["heix"] = "image/heic",
        ["mif1"] = "image/heif",
        ["msf1"] = "image/heif",
        ["avif"] = "image/avif",
        ["qt  "] = "video/quicktime",
        ["M4A "] = "audio/mp4",
        ["3gp4"] = "video/3gpp",
        ["3gp5"] = "video/3gpp",
        ["3g2a"] = "video/3gpp2"
    };

    private static readonly (string EntryPrefix, string MimeType)[] OfficeOpenXmlEntries =
    [
        ("word/", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
        ("xl/", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
        ("ppt/", "application/vnd.openxmlformats-officedocument.presentationml.presentation")
    ];

    public async Task<string?> DetectMimeTypeAsync(Stream content, CancellationToken ct)
    {
        if (!content.CanSeek)
        {
            throw new ArgumentException(
                "Stream phải seek được để đọc magic bytes rồi trả về vị trí cũ.",
                nameof(content));
        }

        var originalPosition = content.Position;
        var buffer = new byte[HeaderLength];

        try
        {
            var read = await content.ReadAtLeastAsync(buffer, HeaderLength, throwOnEndOfStream: false, ct);
            return Detect(buffer.AsSpan(0, read));
        }
        finally
        {
            content.Position = originalPosition;
        }
    }

    private static string? Detect(ReadOnlySpan<byte> header)
    {
        if (DetectRiff(header) is { } riffType)
        {
            return riffType;
        }

        if (DetectIsoMedia(header) is { } isoType)
        {
            return isoType;
        }

        if (header.StartsWith("PK\u0003\u0004"u8))
        {
            return DetectZipFamily(header);
        }

        foreach (var (signature, mimeType) in Signatures)
        {
            if (header.StartsWith(signature))
            {
                return mimeType;
            }
        }

        return null;
    }

    // RIFF....WEBP / WAVE / AVI : cùng tiền tố, phân biệt bằng 4 byte ở offset 8.
    private static string? DetectRiff(ReadOnlySpan<byte> header)
    {
        if (header.Length < 12 || !header.StartsWith("RIFF"u8))
        {
            return null;
        }

        return Encoding.ASCII.GetString(header.Slice(8, 4)) switch
        {
            "WEBP" => "image/webp",
            "WAVE" => "audio/wav",
            "AVI " => "video/x-msvideo",
            _ => null
        };
    }

    // ISO base media (mp4, mov, heic...): "ftyp" ở offset 4, brand chính ở offset 8.
    private static string? DetectIsoMedia(ReadOnlySpan<byte> header)
    {
        if (header.Length < 12 || !header.Slice(4, 4).SequenceEqual("ftyp"u8))
        {
            return null;
        }

        var brand = Encoding.ASCII.GetString(header.Slice(8, 4));
        return IsoMediaBrands.GetValueOrDefault(brand, "video/mp4");
    }

    // docx/xlsx/pptx đều là zip; tên entry ở local file header là chữ ASCII nên tìm thẳng trong phần đầu tệp.
    private static string DetectZipFamily(ReadOnlySpan<byte> header)
    {
        foreach (var (entryPrefix, mimeType) in OfficeOpenXmlEntries)
        {
            if (header.IndexOf(Encoding.ASCII.GetBytes(entryPrefix)) >= 0)
            {
                return mimeType;
            }
        }

        return "application/zip";
    }
}

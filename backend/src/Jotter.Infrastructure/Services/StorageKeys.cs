using System.Text.RegularExpressions;

namespace Jotter.Infrastructure;

// storageKey do server sinh (vd. "attachments/{noteId}/{id}"), không bao giờ lấy từ tên tệp của client.
// Chỉ cho chữ thường, số, '_' và '-' theo từng đoạn nên không thể chứa ".." để thoát khỏi thư mục gốc.
internal static partial class StorageKeys
{
    public const int MaxLength = 200;

    public static bool IsValid(string key) => key.Length <= MaxLength && KeyPattern().IsMatch(key);

    [GeneratedRegex("^[a-z0-9]+(/[a-z0-9_-]+)+$")]
    private static partial Regex KeyPattern();
}

using System.Buffers.Text;
using System.Text.Json;

namespace Jotter.Application;

// Cursor là khoá sắp xếp của phần tử cuối trang, mã hoá base64url để client chỉ coi nó như một chuỗi mờ.
public static class PageCursor
{
    public static string Encode<TKey>(TKey key) =>
        Base64Url.EncodeToString(JsonSerializer.SerializeToUtf8Bytes(key));

    // Cursor rỗng là hợp lệ (trang đầu) và cho ra key = null.
    public static bool TryDecode<TKey>(string? cursor, out TKey? key)
        where TKey : class
    {
        key = null;

        if (string.IsNullOrEmpty(cursor))
        {
            return true;
        }

        try
        {
            key = JsonSerializer.Deserialize<TKey>(Base64Url.DecodeFromChars(cursor));
            return key is not null;
        }
        catch (Exception ex) when (ex is FormatException or JsonException)
        {
            return false;
        }
    }
}

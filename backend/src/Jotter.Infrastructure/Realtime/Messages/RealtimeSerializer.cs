using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.Unicode;

namespace Jotter.Infrastructure;

public static class RealtimeSerializer
{
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web)
    {
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        // Giữ nguyên tên tiếng Việt thay vì escape thành mã \u; ký tự nhạy cảm với HTML vẫn được escape.
        Encoder = JavaScriptEncoder.Create(UnicodeRanges.All),
        Converters = { new JsonStringEnumConverter() }
    };

    // Serialize theo kiểu runtime để giữ đủ thuộc tính của message con.
    public static byte[] Serialize(RealtimeMessage message) =>
        JsonSerializer.SerializeToUtf8Bytes(message, message.GetType(), Options);

    public static ClientMessage? TryDeserialize(ReadOnlySpan<byte> json)
    {
        try
        {
            return JsonSerializer.Deserialize<ClientMessage>(json, Options);
        }
        catch (JsonException)
        {
            return null;
        }
    }
}

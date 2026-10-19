using System.Text.Json.Serialization;

namespace Jotter.Infrastructure;

// Kênh realtime chỉ mang tín hiệu, không bao giờ mang nội dung note.
public abstract record RealtimeMessage([property: JsonPropertyOrder(-1)] string Type);

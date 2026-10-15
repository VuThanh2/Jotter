namespace Jotter.Infrastructure;

// Projection phái sinh từ nội dung note, không mang bất biến nghiệp vụ: xoá sạch rồi dựng lại không mất dữ liệu.
public sealed class NoteEmbedding
{
    public Guid NoteId { get; set; }

    public int ChunkIndex { get; set; }

    public string ChunkText { get; set; } = string.Empty;

    public float[] Vector { get; set; } = [];

    public long IndexedVersion { get; set; }

    public DateTimeOffset IndexedAt { get; set; }
}

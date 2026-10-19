namespace Jotter.Infrastructure;

// Một dòng duy nhất: changeSeq lớn nhất của tombstone đã bị xoá vật lý.
// Client đồng bộ từ mốc thấp hơn giá trị này có thể đã lỡ thao tác xoá, nên phải tải lại toàn bộ.
public sealed class PurgeCheckpoint
{
    public const int SingletonId = 1;

    public int Id { get; set; } = SingletonId;

    public long PurgedChangeSeq { get; set; }

    public DateTimeOffset PurgedAt { get; set; }
}

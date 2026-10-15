namespace Jotter.Infrastructure;

// Chỉ tác vụ dọn tệp mồ côi cần liệt kê kho lưu trữ, nên tách khỏi IFileStorage của Application.
// Mọi chiến lược lưu trữ (Volume, R2...) đều phải hiện thực cả hai.
public interface IFileInventory
{
    IAsyncEnumerable<string> ListKeysModifiedBeforeAsync(DateTimeOffset cutoff, CancellationToken ct);
}

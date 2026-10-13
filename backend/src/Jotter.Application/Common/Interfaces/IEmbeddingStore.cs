namespace Jotter.Application;

// ReplaceAsync và RemoveAsync chỉ ghi nhận thay đổi; Command commit bằng IUnitOfWork.
public interface IEmbeddingStore
{
    // Gồm hai nhóm: note còn sống, có chữ, mà Version > indexedVersion hoặc chưa từng lập chỉ mục;
    // và note đã xoá hoặc đã bị xoá trắng nhưng vẫn còn embedding cũ cần gỡ.
    Task<IReadOnlyList<StaleNote>> ListStaleNotesAsync(int limit, CancellationToken ct);

    Task ReplaceAsync(Guid noteId, long indexedVersion, IReadOnlyList<EmbeddedChunk> chunks, CancellationToken ct);

    Task RemoveAsync(Guid noteId, CancellationToken ct);

    // Chỉ tính độ tương đồng trên đúng tập noteIds truyền vào — tập này đã được lọc quyền từ trước.
    Task<IReadOnlyList<EmbeddingMatch>> SearchAsync(
        IReadOnlyCollection<Guid> noteIds,
        float[] queryVector,
        int topK,
        CancellationToken ct);
}

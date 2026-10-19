namespace Jotter.Application;

// Thành phần DUY NHẤT quyết định quyền trên note — REST, join WebSocket, lọc RAG và phạm vi sync đều đi qua đây.
// Note đã xoá được coi như không tồn tại (NoteAccess.None).
public interface INoteAccessPolicy
{
    Task<NoteAccess> GetAccessAsync(Guid userId, Guid noteId, CancellationToken ct);

    // Phạm vi truy hồi AI: note của mình hoặc được chia sẻ còn hiệu lực, chưa xoá,
    // và nếu đang bảo vệ thì phải có phiên mở khoá còn hạn.
    Task<IReadOnlyList<Guid>> ListContentReadableNoteIdsAsync(Guid userId, CancellationToken ct);
}

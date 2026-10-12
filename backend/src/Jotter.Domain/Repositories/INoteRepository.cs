namespace Jotter.Domain;

// Mọi hàm Get/List trả về nguyên Aggregate (Labels, Attachments, Summary), kể cả note đã tombstone.
public interface INoteRepository
{
    Task<Note?> GetByIdAsync(Guid noteId, CancellationToken ct);

    Task<Note?> GetByAttachmentIdAsync(Guid attachmentId, CancellationToken ct);

    Task<IReadOnlyList<Note>> ListByLabelAsync(Guid labelId, CancellationToken ct);

    // Tính cả note đã xoá: noteId do client sinh nên không được tái sử dụng.
    Task<bool> ExistsAsync(Guid noteId, CancellationToken ct);

    void Add(Note note);
}

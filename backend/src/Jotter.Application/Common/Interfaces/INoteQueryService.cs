namespace Jotter.Application;

// Projection AsNoTracking thẳng ra DTO. Không bao giờ trả note hay attachment đã tombstone.
public interface INoteQueryService
{
    // Phạm vi theo filter.Scope trên tập note người dùng truy cập được (cùng điều kiện với INoteAccessPolicy).
    // Sắp xếp: ghim trước (PinnedAt giảm dần), rồi UpdatedAt giảm dần, rồi NoteId. Note của người khác coi như không ghim.
    // LabelIds lọc theo OR và chỉ khớp được note của chính người dùng.
    // IsShared = note còn ít nhất một ShareGrant chưa thu hồi; hết người nhận thì chỉ báo tự biến mất.
    // Note đang bảo vệ chỉ được đối chiếu SearchText theo nội dung khi người dùng có phiên mở khoá còn hạn.
    Task<IReadOnlyList<ListNotesItemDto>> ListAsync(
        Guid userId,
        ListNotesFilter filter,
        ListNotesCursor? after,
        int take,
        CancellationToken ct);

    // Hiển thị theo access: Content = null và Attachments rỗng khi access.IsLocked;
    // IsPinned, PinnedAt, LabelIds = null khi người gọi không phải chủ sở hữu.
    Task<GetNoteOutputDto?> GetAsync(Guid noteId, NoteAccess access, CancellationToken ct);

    Task<long?> GetVersionAsync(Guid noteId, CancellationToken ct);

    Task<IReadOnlyList<AttachmentDto>> ListAttachmentsAsync(Guid noteId, CancellationToken ct);

    Task<StoredAttachment?> FindAttachmentAsync(Guid attachmentId, CancellationToken ct);

    Task<GetSummaryOutputDto?> GetSummaryAsync(Guid noteId, CancellationToken ct);
}

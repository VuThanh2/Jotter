namespace Jotter.Application;

public interface IShareQueryService
{
    // Đã loại grant bị thu hồi.
    Task<IReadOnlyList<ListSharesItemDto>> ListByNoteAsync(Guid noteId, CancellationToken ct);

    // Grant còn hiệu lực trên note chưa xoá, sắp theo SharedAt giảm dần rồi NoteId.
    // Preview rỗng với note đang bảo vệ.
    Task<IReadOnlyList<ListSharedWithMeItemDto>> ListSharedWithMeAsync(
        Guid recipientUserId,
        ListSharedWithMeCursor? after,
        int take,
        CancellationToken ct);
}

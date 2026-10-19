namespace Jotter.Application;

public interface ISyncQueryService
{
    // ChangeSeq lớn nhất trong số tombstone đã bị tác vụ dọn dẹp xoá vật lý; 0 nếu chưa dọn lần nào.
    Task<long> GetPurgedChangeSeqAsync(CancellationToken ct);

    // Mọi bản ghi có ChangeSeq > since trong phạm vi truy cập của người dùng (cùng điều kiện với INoteAccessPolicy),
    // gồm cả tombstone (deletedAt, revokedAt). Lấy tối đa limit bản ghi theo thứ tự ChangeSeq trên cả bốn loại.
    // Note được chia sẻ sau mốc since vẫn phải được trả về dù ChangeSeq của chính note cũ hơn.
    Task<PullChangesOutputDto> PullAsync(Guid userId, long since, int limit, CancellationToken ct);
}

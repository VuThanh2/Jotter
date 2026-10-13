using Jotter.Domain;

namespace Jotter.Application;

// Endpoint đọc duy nhất của đồng bộ — chiều ghi cố ý không có đường riêng, outbox gọi lại đúng các endpoint ghi thông thường.
public sealed class PullChangesQuery(ICurrentUser currentUser, ISyncQueryService syncQueries)
{
    public const int DefaultLimit = 200;
    public const int MaxLimit = 500;

    public async Task<Result<PullChangesOutputDto>> ExecuteAsync(PullChangesInputDto input, CancellationToken ct)
    {
        var since = input.Since ?? 0;

        // Tombstone sau mốc since có thể đã bị dọn: đồng bộ theo phần lúc này sẽ để dữ liệu đã xoá âm thầm sống lại,
        // nên buộc client đẩy hết outbox rồi tải lại toàn bộ từ since = 0.
        if (since > 0 && since < await syncQueries.GetPurgedChangeSeqAsync(ct))
        {
            return new PullChangesOutputDto(
                Notes: [],
                Labels: [],
                Shares: [],
                Attachments: [],
                NextChangeSeq: 0,
                HasMore: false,
                FullResyncRequired: true);
        }

        return await syncQueries.PullAsync(currentUser.UserId, since, input.Limit ?? DefaultLimit, ct);
    }
}

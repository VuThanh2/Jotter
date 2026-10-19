namespace Jotter.Application;

public interface ILabelQueryService
{
    // Chỉ nhãn chưa xoá của owner, sắp theo tên.
    Task<IReadOnlyList<ListLabelsItemDto>> ListAsync(Guid ownerId, CancellationToken ct);
}

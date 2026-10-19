namespace Jotter.Domain;

public interface ILabelRepository
{
    Task<Label?> GetByIdAsync(Guid labelId, CancellationToken ct);

    // Tính cả nhãn đã xoá: labelId do client sinh nên không được tái sử dụng.
    Task<bool> ExistsAsync(Guid labelId, CancellationToken ct);

    // Chỉ xét nhãn chưa xoá của owner, so sánh không phân biệt hoa thường ("Work" trùng "work").
    Task<bool> IsNameTakenAsync(Guid ownerId, string name, Guid? excludedLabelId, CancellationToken ct);

    Task<bool> AreAllActiveAndOwnedByAsync(Guid ownerId, IReadOnlyCollection<Guid> labelIds, CancellationToken ct);

    void Add(Label label);
}

using Jotter.Domain;

namespace Jotter.Application;

// Note chỉ giữ labelId, nên đổi tên tự phản ánh trên mọi note mà không phải chạm vào chúng.
public sealed class RenameLabelCommand(ICurrentUser currentUser, ILabelRepository labels, IUnitOfWork unitOfWork)
{
    public async Task<Result<RenameLabelOutputDto>> ExecuteAsync(
        Guid labelId,
        RenameLabelInputDto input,
        CancellationToken ct)
    {
        var label = await labels.GetByIdAsync(labelId, ct);
        if (label is null || label.IsDeleted)
        {
            return LabelErrors.NotFound;
        }

        if (label.OwnerId != currentUser.UserId)
        {
            return AccessErrors.Forbidden;
        }

        // Chuẩn hoá tên trước để kiểm trùng trên đúng giá trị sẽ được lưu, mà chưa phải sửa aggregate.
        var nameResult = LabelName.Create(input.Name);
        if (nameResult.IsFailure)
        {
            return nameResult.Error;
        }

        var newName = nameResult.Value.Value;

        if (await labels.IsNameTakenAsync(label.OwnerId, newName, label.Id, ct))
        {
            return LabelErrors.DuplicateName;
        }

        var renamed = label.Rename(newName);
        if (renamed.IsFailure)
        {
            return renamed.Error;
        }

        await unitOfWork.SaveChangesAsync(ct);

        return LabelMapper.ToRenameLabelOutputDto(label);
    }
}

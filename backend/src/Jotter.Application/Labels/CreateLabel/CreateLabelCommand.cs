using Jotter.Domain;

namespace Jotter.Application;

public sealed class CreateLabelCommand(ICurrentUser currentUser, ILabelRepository labels, IUnitOfWork unitOfWork)
{
    public async Task<Result<CreateLabelOutputDto>> ExecuteAsync(CreateLabelInputDto input, CancellationToken ct)
    {
        // labelId do client sinh để tạo nhãn khi ngoại tuyến rồi gắn ngay cho note; không được tái sử dụng.
        if (await labels.ExistsAsync(input.LabelId, ct))
        {
            return LabelErrors.IdAlreadyExists;
        }

        var created = Label.Create(input.LabelId, currentUser.UserId, input.Name);
        if (created.IsFailure)
        {
            return created.Error;
        }

        var label = created.Value;

        // Kiểm trùng trên tên đã được Value Object chuẩn hoá, không phải chuỗi thô client gửi.
        if (await labels.IsNameTakenAsync(label.OwnerId, label.Name, excludedLabelId: null, ct))
        {
            return LabelErrors.DuplicateName;
        }

        labels.Add(label);

        await unitOfWork.SaveChangesAsync(ct);

        return LabelMapper.ToCreateLabelOutputDto(label);
    }
}

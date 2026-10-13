using Jotter.Domain;

namespace Jotter.Application;

public sealed class UploadAvatarCommand(
    ICurrentUser currentUser,
    IUserRepository users,
    IFileTypeDetector fileTypes,
    IFileStorage storage,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result<UploadAvatarOutputDto>> ExecuteAsync(FileUploadDto file, CancellationToken ct)
    {
        var user = await users.GetByIdAsync(currentUser.UserId, ct);
        if (user is null)
        {
            return UserErrors.NotFound;
        }

        var fileCheck = await EnsureValidAvatarAsync(file, ct);
        if (fileCheck.IsFailure)
        {
            return fileCheck.Error;
        }

        // Key mới cho mỗi lần tải lên: bytes cũ không còn được ai tham chiếu và để FileCleanupJobService dọn,
        // tách khỏi transaction để một lỗi lưu trữ không làm hỏng thao tác đổi ảnh.
        var storageKey = $"avatars/{user.Id:N}/{Guid.CreateVersion7(clock.GetUtcNow()):N}";
        user.SetAvatar(storageKey);

        await storage.SaveAsync(storageKey, file.Content, ct);
        await unitOfWork.SaveChangesAsync(ct);

        return UserMapper.ToUploadAvatarOutputDto(user);
    }

    // Kiểm kích thước trước để không phải đọc magic bytes của một tệp chắc chắn bị từ chối.
    private async Task<Result> EnsureValidAvatarAsync(FileUploadDto file, CancellationToken ct)
    {
        if (file.SizeBytes <= 0)
        {
            return FileErrors.EmptyFile;
        }

        if (file.SizeBytes > User.MaxAvatarSizeBytes)
        {
            return FileErrors.FileTooLarge;
        }

        var mimeType = await fileTypes.DetectMimeTypeAsync(file.Content, ct);
        if (mimeType is null || !User.AvatarMimeTypes.Contains(mimeType))
        {
            return FileErrors.UnsupportedMediaType;
        }

        return Result.Success();
    }
}

using Jotter.Domain;

namespace Jotter.Application;

// Endpoint công khai: thẻ ảnh trên trình duyệt không gắn được header Authorization.
public sealed class GetAvatarQuery(IUserRepository users, IFileStorage storage, IFileTypeDetector fileTypes)
{
    public async Task<Result<GetAvatarOutputDto>> ExecuteAsync(Guid userId, CancellationToken ct)
    {
        var user = await users.GetByIdAsync(userId, ct);
        if (user?.AvatarStorageKey is not { } storageKey)
        {
            return ProfileErrors.AvatarNotFound;
        }

        var content = await storage.OpenReadAsync(storageKey, ct);

        // MIME không lưu trong DB: đọc lại magic bytes, vốn đã được kiểm thuộc danh sách cho phép lúc tải lên.
        // Từ đây controller giữ quyền dispose stream; trước đó mà lỗi thì phải tự đóng.
        string? mimeType;
        try
        {
            mimeType = await fileTypes.DetectMimeTypeAsync(content, ct);
        }
        catch
        {
            await content.DisposeAsync();
            throw;
        }

        return new GetAvatarOutputDto(content, mimeType ?? "application/octet-stream");
    }
}

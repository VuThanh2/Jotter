using Jotter.Domain;

namespace Jotter.Application;

// Đọc một aggregate theo id nên dùng repository; QueryService chỉ cần cho danh sách, tìm kiếm và projection nhiều bảng.
public sealed class GetMeQuery(ICurrentUser currentUser, IUserRepository users)
{
    public async Task<Result<GetMeOutputDto>> ExecuteAsync(CancellationToken ct)
    {
        var user = await users.GetByIdAsync(currentUser.UserId, ct);
        if (user is null)
        {
            return UserErrors.NotFound;
        }

        return UserMapper.ToGetMeOutputDto(user);
    }
}

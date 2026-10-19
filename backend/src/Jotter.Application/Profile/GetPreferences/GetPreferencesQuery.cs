using Jotter.Domain;

namespace Jotter.Application;

// Preferences được tạo mặc định cùng User nên luôn có giá trị, không bao giờ 404.
public sealed class GetPreferencesQuery(ICurrentUser currentUser, IUserRepository users)
{
    public async Task<Result<GetPreferencesOutputDto>> ExecuteAsync(CancellationToken ct)
    {
        var user = await users.GetByIdAsync(currentUser.UserId, ct);
        if (user is null)
        {
            return UserErrors.NotFound;
        }

        return UserMapper.ToGetPreferencesOutputDto(user.Preferences);
    }
}

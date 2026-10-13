using Jotter.Domain;

namespace Jotter.Application;

public sealed class UpdateProfileCommand(ICurrentUser currentUser, IUserRepository users, IUnitOfWork unitOfWork)
{
    public async Task<Result<UpdateProfileOutputDto>> ExecuteAsync(UpdateProfileInputDto input, CancellationToken ct)
    {
        var user = await users.GetByIdAsync(currentUser.UserId, ct);
        if (user is null)
        {
            return UserErrors.NotFound;
        }

        // Chỉ đổi DisplayName của Domain; UserName của Identity giữ nguyên là email vì không nhận tiếng Việt có dấu.
        var updated = user.UpdateDisplayName(input.DisplayName);
        if (updated.IsFailure)
        {
            return updated.Error;
        }

        await unitOfWork.SaveChangesAsync(ct);

        return UserMapper.ToUpdateProfileOutputDto(user);
    }
}

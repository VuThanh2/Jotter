using Jotter.Domain;

namespace Jotter.Application;

public sealed class RemoveAvatarCommand(ICurrentUser currentUser, IUserRepository users, IUnitOfWork unitOfWork)
{
    // Bytes do FileCleanupJobService dọn sau, tách khỏi transaction nghiệp vụ.
    public async Task<Result> ExecuteAsync(CancellationToken ct)
    {
        var user = await users.GetByIdAsync(currentUser.UserId, ct);
        if (user is null)
        {
            return UserErrors.NotFound;
        }

        user.RemoveAvatar();

        await unitOfWork.SaveChangesAsync(ct);

        return Result.Success();
    }
}

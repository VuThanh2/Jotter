using Jotter.Domain;
using Microsoft.AspNetCore.Identity;

namespace Jotter.Application;

public sealed class LoginCommand(
    UserManager<User> userManager,
    IUserRepository users,
    IUserSessionRepository sessions,
    ITokenService tokens,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result<LoginOutputDto>> ExecuteAsync(LoginInputDto input, CancellationToken ct)
    {
        // Mọi trường hợp sai đều trả cùng một lỗi chung, không cho biết sai email hay sai mật khẩu.
        var user = await users.GetByEmailAsync(input.Email, ct);
        if (user is null)
        {
            return UserErrors.InvalidCredentials;
        }

        var passwordCheck = await CheckPasswordWithLockoutAsync(user, input.Password);

        if (passwordCheck.IsFailure)
        {
            // Lưu cả khi thất bại để bộ đếm đăng nhập sai của Identity tăng thật.
            await unitOfWork.SaveChangesAsync(ct);
            return passwordCheck.Error;
        }

        var session = UserSession.Start(user.Id, clock.GetUtcNow());
        sessions.Add(session);

        await unitOfWork.SaveChangesAsync(ct);

        return UserMapper.ToLoginOutputDto(user, tokens.IssueAccessToken(user, session));
    }

    // Tương đương SignInManager.CheckPasswordSignInAsync(lockoutOnFailure: true).
    // SignInManager thuộc ASP.NET Core nên Application chỉ dùng được các khối dựng của UserManager.
    private async Task<Result> CheckPasswordWithLockoutAsync(User user, string password)
    {
        if (await userManager.IsLockedOutAsync(user))
        {
            return UserErrors.AccountLockedOut;
        }

        if (await userManager.CheckPasswordAsync(user, password))
        {
            await userManager.ResetAccessFailedCountAsync(user);
            return Result.Success();
        }

        await userManager.AccessFailedAsync(user);

        return await userManager.IsLockedOutAsync(user)
            ? UserErrors.AccountLockedOut
            : UserErrors.InvalidCredentials;
    }
}

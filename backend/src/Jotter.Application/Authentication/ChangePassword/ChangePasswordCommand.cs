using Jotter.Domain;
using Microsoft.AspNetCore.Identity;

namespace Jotter.Application;

public sealed class ChangePasswordCommand(
    ICurrentUser currentUser,
    UserManager<User> userManager,
    IUserRepository users,
    IUserSessionRepository sessions,
    ITokenService tokens,
    IUnitOfWork unitOfWork)
{
    public async Task<Result<ChangePasswordOutputDto>> ExecuteAsync(ChangePasswordInputDto input, CancellationToken ct)
    {
        var user = await users.GetByIdAsync(currentUser.UserId, ct);
        if (user is null)
        {
            return UserErrors.NotFound;
        }

        var session = await sessions.GetByIdAsync(currentUser.SessionId, ct)
            ?? throw new InvalidOperationException("Phiên của request đã xác thực phải tồn tại.");

        if (!await userManager.CheckPasswordAsync(user, input.CurrentPassword))
        {
            return UserErrors.InvalidCurrentPassword;
        }

        // Identity chỉ kiểm mật khẩu hiện tại rồi ghi đè, không chặn mật khẩu mới trùng mật khẩu cũ.
        if (input.NewPassword == input.CurrentPassword)
        {
            return UserErrors.SamePassword;
        }

        var changed = await userManager.ChangePasswordAsync(user, input.CurrentPassword, input.NewPassword);
        if (!changed.Succeeded)
        {
            return IdentityErrorMapper.ToError(changed);
        }

        await unitOfWork.SaveChangesAsync(ct);

        // Stamp vừa xoay nên token cũ của mọi thiết bị đều chết; cấp lại ngay để thiết bị hiện tại không tự đá chính mình.
        var token = tokens.IssueAccessToken(user, session);
        return new ChangePasswordOutputDto(token.Value, token.ExpiresAt);
    }
}

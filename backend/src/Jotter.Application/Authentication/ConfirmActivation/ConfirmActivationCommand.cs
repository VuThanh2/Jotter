using Jotter.Domain;
using Microsoft.AspNetCore.Identity;

namespace Jotter.Application;

public sealed class ConfirmActivationCommand(
    ICurrentUser currentUser,
    UserManager<User> userManager,
    IUserRepository users,
    IUserSessionRepository sessions,
    IVerificationCodeRepository verificationCodes,
    IOtpService otp,
    ITokenService tokens,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result<ConfirmActivationOutputDto>> ExecuteAsync(
        ConfirmActivationInputDto input,
        CancellationToken ct)
    {
        var user = await users.GetByIdAsync(currentUser.UserId, ct);
        if (user is null)
        {
            return UserErrors.NotFound;
        }

        if (user.EmailConfirmed)
        {
            return UserErrors.AlreadyActivated;
        }

        var session = await sessions.GetByIdAsync(currentUser.SessionId, ct)
            ?? throw new InvalidOperationException("Phiên của request đã xác thực phải tồn tại.");

        var code = await verificationCodes.GetPendingAsync(user.Id, OtpPurpose.AccountActivation, ct);
        if (code is null)
        {
            return OtpErrors.InvalidCode;
        }

        var redeemed = code.Redeem(otp.Hash(input.Code), clock.GetUtcNow());
        if (redeemed.IsFailure)
        {
            // Lưu cả khi thất bại để AttemptCount tăng thật — đó là chỗ thi hành giới hạn số lần nhập sai.
            await unitOfWork.SaveChangesAsync(ct);
            return redeemed.Error;
        }

        // OTP của mình chỉ đứng gác; cờ xác minh email vẫn được đặt qua đường của Identity.
        var confirmationToken = await userManager.GenerateEmailConfirmationTokenAsync(user);
        var confirmed = await userManager.ConfirmEmailAsync(user, confirmationToken);
        if (!confirmed.Succeeded)
        {
            throw new InvalidOperationException("Identity từ chối token xác minh vừa tự sinh.");
        }

        await unitOfWork.SaveChangesAsync(ct);

        return UserMapper.ToConfirmActivationOutputDto(user, tokens.IssueAccessToken(user, session));
    }
}

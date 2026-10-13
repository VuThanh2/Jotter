using Jotter.Domain;
using Microsoft.AspNetCore.Identity;

namespace Jotter.Application;

public sealed class RegisterCommand(
    UserManager<User> userManager,
    IUserSessionRepository sessions,
    IVerificationCodeRepository verificationCodes,
    IOtpService otp,
    ITokenService tokens,
    IEmailSender emailSender,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result<RegisterOutputDto>> ExecuteAsync(RegisterInputDto input, CancellationToken ct)
    {
        var now = clock.GetUtcNow();

        var userResult = User.Create(input.Email, input.DisplayName, now);
        if (userResult.IsFailure)
        {
            return userResult.Error;
        }

        var user = userResult.Value;

        // Identity băm mật khẩu, cấp securityStamp, kiểm email trùng và độ phức tạp mật khẩu.
        var created = await userManager.CreateAsync(user, input.Password);
        if (!created.Succeeded)
        {
            return IdentityErrorMapper.ToError(created);
        }

        // Đăng ký xong là đăng nhập luôn — chưa kích hoạt vẫn dùng được toàn bộ chức năng.
        var session = UserSession.Start(user.Id, now);
        sessions.Add(session);

        var activationCode = otp.GenerateCode();
        verificationCodes.Add(VerificationCode.Issue(
            user.Id,
            OtpPurpose.AccountActivation,
            otp.Hash(activationCode),
            pendingCode: null,
            now));

        await unitOfWork.SaveChangesAsync(ct);

        await emailSender.SendActivationCodeAsync(user.Email!, user.DisplayName, activationCode, ct);

        return UserMapper.ToRegisterOutputDto(user, tokens.IssueAccessToken(user, session));
    }
}

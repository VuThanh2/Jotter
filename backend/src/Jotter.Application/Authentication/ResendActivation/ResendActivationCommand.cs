using Jotter.Domain;

namespace Jotter.Application;

public sealed class ResendActivationCommand(
    ICurrentUser currentUser,
    IUserRepository users,
    IVerificationCodeRepository verificationCodes,
    IOtpService otp,
    IEmailSender emailSender,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    private const OtpPurpose Purpose = OtpPurpose.AccountActivation;

    public async Task<Result<ResendActivationOutputDto>> ExecuteAsync(CancellationToken ct)
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

        var now = clock.GetUtcNow();

        var latestCode = await verificationCodes.GetLatestAsync(user.Id, Purpose, ct);
        var waitTime = latestCode?.GetResendWaitTime(now) ?? TimeSpan.Zero;
        if (waitTime > TimeSpan.Zero)
        {
            return OtpErrors.ResendTooSoon.WithDetails("cooldownSeconds", ToWholeSeconds(waitTime));
        }

        // Cấp mã mới vô hiệu mã cũ cùng purpose để không bao giờ có hai mã cùng sống.
        var pendingCode = await verificationCodes.GetPendingAsync(user.Id, Purpose, ct);
        var activationCode = otp.GenerateCode();
        verificationCodes.Add(VerificationCode.Issue(user.Id, Purpose, otp.Hash(activationCode), pendingCode, now));

        await unitOfWork.SaveChangesAsync(ct);

        await emailSender.SendActivationCodeAsync(user.Email!, user.DisplayName, activationCode, ct);

        return new ResendActivationOutputDto(ToWholeSeconds(VerificationCode.ResendCooldown));
    }

    private static int ToWholeSeconds(TimeSpan duration) => (int)Math.Ceiling(duration.TotalSeconds);
}

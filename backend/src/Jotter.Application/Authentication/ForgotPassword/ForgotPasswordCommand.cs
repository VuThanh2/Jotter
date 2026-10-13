using Jotter.Domain;

namespace Jotter.Application;

// Gọi lại chính use case này là chức năng "Gửi lại mã".
public sealed class ForgotPasswordCommand(
    IUserRepository users,
    IVerificationCodeRepository verificationCodes,
    IOtpService otp,
    IEmailSender emailSender,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    private const OtpPurpose Purpose = OtpPurpose.PasswordReset;

    // Mọi nhánh đều trả cùng một kết quả thành công để không lộ email nào có tài khoản — kể cả khi đang trong
    // thời gian chờ gửi lại. 429 do rate limiter của Api áp đồng đều, không phụ thuộc email có tồn tại hay không.
    public async Task<Result> ExecuteAsync(ForgotPasswordInputDto input, CancellationToken ct)
    {
        var user = await users.GetByEmailAsync(input.Email, ct);
        if (user is null)
        {
            return Result.Success();
        }

        var now = clock.GetUtcNow();

        var latestCode = await verificationCodes.GetLatestAsync(user.Id, Purpose, ct);
        if (latestCode is not null && latestCode.GetResendWaitTime(now) > TimeSpan.Zero)
        {
            return Result.Success();
        }

        var pendingCode = await verificationCodes.GetPendingAsync(user.Id, Purpose, ct);
        var resetCode = otp.GenerateCode();
        verificationCodes.Add(VerificationCode.Issue(user.Id, Purpose, otp.Hash(resetCode), pendingCode, now));

        await unitOfWork.SaveChangesAsync(ct);

        await emailSender.SendPasswordResetCodeAsync(user.Email!, user.DisplayName, resetCode, ct);

        return Result.Success();
    }
}

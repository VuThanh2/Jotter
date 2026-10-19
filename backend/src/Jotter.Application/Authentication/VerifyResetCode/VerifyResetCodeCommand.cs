using Jotter.Domain;

namespace Jotter.Application;

public sealed class VerifyResetCodeCommand(
    IUserRepository users,
    IVerificationCodeRepository verificationCodes,
    IPasswordResetTicketRepository resetTickets,
    IOtpService otp,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result<VerifyResetCodeOutputDto>> ExecuteAsync(VerifyResetCodeInputDto input, CancellationToken ct)
    {
        // Email không tồn tại trả cùng lỗi với mã sai để không lộ danh sách tài khoản.
        var user = await users.GetByEmailAsync(input.Email, ct);
        if (user is null)
        {
            return OtpErrors.InvalidCode;
        }

        var code = await verificationCodes.GetPendingAsync(user.Id, OtpPurpose.PasswordReset, ct);
        if (code is null)
        {
            return OtpErrors.InvalidCode;
        }

        var now = clock.GetUtcNow();

        // Tiêu thụ mã ngay tại đây — đây là chỗ thi hành "chỉ dùng một lần" của OTP.
        var redeemed = code.Redeem(otp.Hash(input.Code), now);
        if (redeemed.IsFailure)
        {
            await unitOfWork.SaveChangesAsync(ct);
            return redeemed.Error;
        }

        var ticketValue = otp.GenerateTicket();
        var ticket = PasswordResetTicket.Issue(user.Id, otp.Hash(ticketValue), now);
        resetTickets.Add(ticket);

        await unitOfWork.SaveChangesAsync(ct);

        return new VerifyResetCodeOutputDto(ticketValue, ticket.ExpiresAt);
    }
}

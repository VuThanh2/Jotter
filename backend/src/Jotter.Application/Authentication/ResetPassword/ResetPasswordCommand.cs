using Jotter.Domain;
using Microsoft.AspNetCore.Identity;

namespace Jotter.Application;

public sealed class ResetPasswordCommand(
    UserManager<User> userManager,
    IUserRepository users,
    IPasswordResetTicketRepository resetTickets,
    IOtpService otp,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result> ExecuteAsync(ResetPasswordInputDto input, CancellationToken ct)
    {
        var ticket = await resetTickets.GetByHashAsync(otp.Hash(input.ResetTicket), ct);
        if (ticket is null)
        {
            return OtpErrors.InvalidResetTicket;
        }

        var now = clock.GetUtcNow();

        // Chỉ kiểm, chưa tiêu thụ: mật khẩu mới bị Identity từ chối thì người dùng vẫn dùng lại được ticket.
        var redeemable = ticket.EnsureRedeemable(now);
        if (redeemable.IsFailure)
        {
            return redeemable.Error;
        }

        var user = await users.GetByIdAsync(ticket.UserId, ct);
        if (user is null)
        {
            return OtpErrors.InvalidResetTicket;
        }

        // Identity không tự chặn đặt lại đúng mật khẩu đang dùng.
        if (await userManager.CheckPasswordAsync(user, input.NewPassword))
        {
            return UserErrors.SamePassword;
        }

        // Identity vẫn là nơi duy nhất băm mật khẩu và xoay securityStamp — stamp đổi nên mọi phiên đang mở đều chết.
        var resetToken = await userManager.GeneratePasswordResetTokenAsync(user);
        var reset = await userManager.ResetPasswordAsync(user, resetToken, input.NewPassword);
        if (!reset.Succeeded)
        {
            return IdentityErrorMapper.ToError(reset);
        }

        ticket.Redeem(now);

        await unitOfWork.SaveChangesAsync(ct);

        return Result.Success();
    }
}

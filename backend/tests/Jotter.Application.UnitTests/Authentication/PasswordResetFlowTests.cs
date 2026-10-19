using Jotter.Domain;
using Microsoft.AspNetCore.Identity;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

// UC-06 gồm ba bước: ForgotPassword → VerifyResetCode → ResetPassword.
public sealed class PasswordResetFlowTests
{
    private static readonly DateTimeOffset RequestTime = TestData.Now.AddMinutes(1);

    private readonly User _user = TestData.NewUser("an@jotter.app", "An");
    private readonly UserManager<User> _userManager = TestData.NewUserManager();
    private readonly IUserRepository _users = Substitute.For<IUserRepository>();
    private readonly IVerificationCodeRepository _codes = Substitute.For<IVerificationCodeRepository>();
    private readonly IPasswordResetTicketRepository _tickets = Substitute.For<IPasswordResetTicketRepository>();
    private readonly IOtpService _otp = Substitute.For<IOtpService>();
    private readonly IEmailSender _emailSender = Substitute.For<IEmailSender>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();
    private readonly TimeProvider _clock = new FixedClock(RequestTime);

    public PasswordResetFlowTests()
    {
        _users.GetByEmailAsync(Arg.Any<string>(), Arg.Any<CancellationToken>()).Returns((User?)null);
        _users.GetByEmailAsync(_user.Email!, Arg.Any<CancellationToken>()).Returns(_user);
        _users.GetByIdAsync(_user.Id, Arg.Any<CancellationToken>()).Returns(_user);
        _otp.Hash(Arg.Any<string>()).Returns(call => "h:" + call.Arg<string>());
        _otp.GenerateCode().Returns("654321");
        _otp.GenerateTicket().Returns("ticket");
    }

    // Không được để lộ email nào có tài khoản: email lạ và email thật đều nhận cùng một kết quả.
    [Fact]
    public async Task Forgot_UnknownEmail_SucceedsSilently()
    {
        var result = await ForgotAsync("ai-do@jotter.app");

        Assert.True(result.IsSuccess);
        _codes.DidNotReceive().Add(Arg.Any<VerificationCode>());
        await _emailSender.DidNotReceive().SendPasswordResetCodeAsync(
            Arg.Any<string>(), Arg.Any<string>(), Arg.Any<string>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Forgot_WithinResendCooldown_SucceedsWithoutIssuingAnotherCode()
    {
        GivenLatestCode(IssueCode(issuedAt: RequestTime.AddSeconds(-10)));

        var result = await ForgotAsync(_user.Email!);

        Assert.True(result.IsSuccess);
        _codes.DidNotReceive().Add(Arg.Any<VerificationCode>());
    }

    // Mỗi (user, purpose) chỉ được có một mã còn sống: mã mới phải vô hiệu mã cũ.
    [Fact]
    public async Task Forgot_AfterCooldown_InvalidatesPendingCode_AndEmailsTheNewOne()
    {
        var pending = IssueCode(issuedAt: RequestTime.AddMinutes(-5));
        GivenLatestCode(pending);
        _codes.GetPendingAsync(_user.Id, OtpPurpose.PasswordReset, Arg.Any<CancellationToken>()).Returns(pending);

        await ForgotAsync(_user.Email!);

        Assert.False(pending.IsPending);
        _codes.Received(1).Add(Arg.Is<VerificationCode>(c => c.CodeHash == "h:654321" && c.IsPending));
        await _emailSender.Received(1).SendPasswordResetCodeAsync(
            _user.Email!, "An", "654321", Arg.Any<CancellationToken>());
    }

    // Không lưu lần nhập sai thì giới hạn số lần thử chỉ có trên giấy.
    [Fact]
    public async Task Verify_WrongCode_PersistsAttempt_AndIssuesNoTicket()
    {
        var code = GivenPendingCode();

        var result = await VerifyAsync("000000");

        Assert.Equal(OtpErrors.InvalidCode, result.Error);
        Assert.Equal(1, code.AttemptCount);
        await _unitOfWork.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
        _tickets.DidNotReceive().Add(Arg.Any<PasswordResetTicket>());
    }

    [Fact]
    public async Task Verify_CorrectCode_ConsumesCode_AndStoresOnlyTicketHash()
    {
        var code = GivenPendingCode();

        var result = await VerifyAsync("123456");

        Assert.Equal("ticket", result.Value.ResetTicket);
        Assert.NotNull(code.ConsumedAt);
        _tickets.Received(1).Add(Arg.Is<PasswordResetTicket>(t => t.TicketHash == "h:ticket" && t.UserId == _user.Id));
    }

    // Identity từ chối mật khẩu mới thì ticket vẫn phải dùng lại được, không bắt người dùng nhập lại mã.
    [Fact]
    public async Task Reset_PasswordRejectedByIdentity_KeepsTicketUsable()
    {
        var ticket = GivenTicket();
        _userManager.GeneratePasswordResetTokenAsync(_user).Returns("identity-token");
        _userManager.ResetPasswordAsync(_user, "identity-token", "ngan")
            .Returns(IdentityResult.Failed(new IdentityError { Code = "PasswordTooShort", Description = "Quá ngắn" }));

        var result = await ResetAsync("ngan");

        Assert.Equal(UserErrors.PasswordTooWeak.Code, result.Error.Code);
        Assert.True(ticket.EnsureRedeemable(RequestTime).IsSuccess);
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Reset_ToCurrentPassword_IsRejectedBeforeTouchingIdentity()
    {
        GivenTicket();
        _userManager.CheckPasswordAsync(_user, "MatKhauCu1!").Returns(true);

        var result = await ResetAsync("MatKhauCu1!");

        Assert.Equal(UserErrors.SamePassword, result.Error);
        await _userManager.DidNotReceive().ResetPasswordAsync(Arg.Any<User>(), Arg.Any<string>(), Arg.Any<string>());
    }

    [Fact]
    public async Task Reset_Success_ConsumesTicket()
    {
        var ticket = GivenTicket();
        _userManager.GeneratePasswordResetTokenAsync(_user).Returns("identity-token");
        _userManager.ResetPasswordAsync(_user, "identity-token", "MatKhauMoi1!").Returns(IdentityResult.Success);

        var result = await ResetAsync("MatKhauMoi1!");

        Assert.True(result.IsSuccess);
        Assert.Equal(OtpErrors.InvalidResetTicket, ticket.EnsureRedeemable(RequestTime).Error);
    }

    private VerificationCode IssueCode(DateTimeOffset issuedAt) =>
        VerificationCode.Issue(_user.Id, OtpPurpose.PasswordReset, "h:111111", pendingCode: null, issuedAt);

    private void GivenLatestCode(VerificationCode code) =>
        _codes.GetLatestAsync(_user.Id, OtpPurpose.PasswordReset, Arg.Any<CancellationToken>()).Returns(code);

    private VerificationCode GivenPendingCode()
    {
        var code = VerificationCode.Issue(_user.Id, OtpPurpose.PasswordReset, "h:123456", pendingCode: null, TestData.Now);
        _codes.GetPendingAsync(_user.Id, OtpPurpose.PasswordReset, Arg.Any<CancellationToken>()).Returns(code);
        return code;
    }

    private PasswordResetTicket GivenTicket()
    {
        var ticket = PasswordResetTicket.Issue(_user.Id, "h:ticket", TestData.Now);
        _tickets.GetByHashAsync("h:ticket", Arg.Any<CancellationToken>()).Returns(ticket);
        return ticket;
    }

    private Task<Result> ForgotAsync(string email) =>
        new ForgotPasswordCommand(_users, _codes, _otp, _emailSender, _unitOfWork, _clock)
            .ExecuteAsync(new ForgotPasswordInputDto(email), TestData.Ct);

    private Task<Result<VerifyResetCodeOutputDto>> VerifyAsync(string code) =>
        new VerifyResetCodeCommand(_users, _codes, _tickets, _otp, _unitOfWork, _clock)
            .ExecuteAsync(new VerifyResetCodeInputDto(_user.Email!, code), TestData.Ct);

    private Task<Result> ResetAsync(string newPassword) =>
        new ResetPasswordCommand(_userManager, _users, _tickets, _otp, _unitOfWork, _clock)
            .ExecuteAsync(new ResetPasswordInputDto("ticket", newPassword, newPassword), TestData.Ct);
}

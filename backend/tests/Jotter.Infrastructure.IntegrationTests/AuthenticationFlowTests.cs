using Jotter.Application;
using Jotter.Domain;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Các luồng này chỉ chạy đúng khi Identity (AutoSaveChanges tắt), token provider, OTP và SessionValidator
// phối hợp với nhau — từng phần đúng riêng lẻ chưa đủ, nên kiểm trọn luồng trên DB thật.
public sealed class AuthenticationFlowTests(PostgresFixture postgres) : DatabaseTest(postgres)
{
    private const string NewPassword = "N3wPassw0rd!";

    [Fact]
    public async Task Activation_WithTheEmailedCode_SetsIdentitysConfirmedFlag_AndTheCodeWorksOnce()
    {
        var account = await Host.SignUpAsync();
        Host.ActAs(account);
        var code = Host.Emails.LastCodeSentTo(account.Email);

        var wrong = await ConfirmAsync(code == "000000" ? "111111" : "000000");
        var confirmed = await ConfirmAsync(code);
        var replayed = await ConfirmAsync(code);

        Assert.Equal(OtpErrors.InvalidCode, wrong.Error);
        Assert.True(confirmed.Value.IsActivated);
        Assert.True(await Host.IsSignedInAsync(confirmed.Value.AccessToken));
        Assert.True((await Host.RunAsync((GetMeQuery me) => me.ExecuteAsync(Ct))).Value.IsActivated);
        Assert.Equal(UserErrors.AlreadyActivated, replayed.Error);
    }

    [Fact]
    public async Task PasswordReset_SignsOutEveryDevice_AndBothCodeAndTicketAreSingleUse()
    {
        var phone = await Host.SignUpAsync();
        var laptop = await Host.SignInAsync(phone.Email);

        await Host.RunAsync((ForgotPasswordCommand forgot) =>
            forgot.ExecuteAsync(new ForgotPasswordInputDto(phone.Email), Ct));
        var code = Host.Emails.LastCodeSentTo(phone.Email);

        var verified = await VerifyAsync(phone.Email, code);
        var codeReplayed = await VerifyAsync(phone.Email, code);
        var reset = await ResetAsync(verified.Value.ResetTicket);
        var ticketReplayed = await ResetAsync(verified.Value.ResetTicket);

        Assert.True(reset.IsSuccess);
        Assert.Equal(OtpErrors.InvalidCode, codeReplayed.Error);
        Assert.Equal(OtpErrors.InvalidResetTicket, ticketReplayed.Error);
        Assert.False(await Host.IsSignedInAsync(phone.AccessToken));
        Assert.False(await Host.IsSignedInAsync(laptop.AccessToken));

        var oldPassword = await Host.RunAsync((LoginCommand login) =>
            login.ExecuteAsync(new LoginInputDto(phone.Email, Password), Ct));
        Assert.Equal(UserErrors.InvalidCredentials, oldPassword.Error);
        Assert.True(await Host.IsSignedInAsync((await Host.SignInAsync(phone.Email, NewPassword)).AccessToken));
    }

    [Fact]
    public async Task ChangePassword_KeepsThisDeviceSignedInWithTheNewToken_ButSignsOutTheOthers()
    {
        var phone = await Host.SignUpAsync();
        var laptop = await Host.SignInAsync(phone.Email);
        Host.ActAs(phone);

        var changed = await Host.RunAsync((ChangePasswordCommand change) =>
            change.ExecuteAsync(new ChangePasswordInputDto(Password, NewPassword, NewPassword), Ct));

        Assert.True(await Host.IsSignedInAsync(changed.Value.AccessToken));
        Assert.False(await Host.IsSignedInAsync(phone.AccessToken));
        Assert.False(await Host.IsSignedInAsync(laptop.AccessToken));
    }

    // Đăng xuất chỉ thu hồi đúng phiên của thiết bị này (không xoay securityStamp), nhưng phải huỷ phiên mở khoá note.
    [Fact]
    public async Task Logout_EndsOnlyThisDevice_AndRelocksUnlockedNotes()
    {
        var phone = await Host.SignUpAsync();
        var laptop = await Host.SignInAsync(phone.Email);
        var noteId = await Host.CreateNoteAsync(phone);
        await Host.ProtectAndLockAsync(phone, noteId, "1234");

        Host.ActAs(phone);
        await Host.RunAsync((UnlockNoteCommand unlock) => unlock.ExecuteAsync(noteId, new UnlockNoteInputDto("1234"), Ct));
        await Host.RunAsync((LogoutCommand logout) => logout.ExecuteAsync(Ct));

        Assert.False(await Host.IsSignedInAsync(phone.AccessToken));
        Assert.True(await Host.IsSignedInAsync(laptop.AccessToken));

        Host.ActAs(laptop);
        var note = await Host.RunAsync((GetNoteQuery get) => get.ExecuteAsync(noteId, Ct));
        Assert.Equal(AccessErrors.NoteLocked.Code, note.Error.Code);
    }

    private Task<Result<ConfirmActivationOutputDto>> ConfirmAsync(string code) =>
        Host.RunAsync((ConfirmActivationCommand confirm) =>
            confirm.ExecuteAsync(new ConfirmActivationInputDto(code), Ct));

    private Task<Result<VerifyResetCodeOutputDto>> VerifyAsync(string email, string code) =>
        Host.RunAsync((VerifyResetCodeCommand verify) =>
            verify.ExecuteAsync(new VerifyResetCodeInputDto(email, code), Ct));

    private Task<Result> ResetAsync(string ticket) =>
        Host.RunAsync((ResetPasswordCommand reset) =>
            reset.ExecuteAsync(new ResetPasswordInputDto(ticket, NewPassword, NewPassword), Ct));
}

using Xunit;

namespace Jotter.Domain.UnitTests;

public sealed class VerificationCodeTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 12, 8, 0, 0, TimeSpan.Zero);
    private static readonly Guid UserId = Guid.CreateVersion7();

    [Fact]
    public void Redeem_ConsumesOnce()
    {
        var code = Issue("h");

        Assert.True(code.Redeem("h", Now).IsSuccess);
        Assert.Equal(OtpErrors.InvalidCode, code.Redeem("h", Now).Error);
    }

    [Fact]
    public void Redeem_RejectsExpiredCode()
    {
        var code = Issue("h");

        Assert.Equal(OtpErrors.CodeExpired, code.Redeem("h", Now + VerificationCode.Lifetime).Error);
    }

    [Fact]
    public void Redeem_LocksAfterMaxWrongAttempts()
    {
        var code = Issue("h");

        for (var i = 1; i < VerificationCode.MaxAttempts; i++)
        {
            Assert.Equal(OtpErrors.InvalidCode, code.Redeem("wrong", Now).Error);
        }

        Assert.Equal(OtpErrors.TooManyAttempts, code.Redeem("wrong", Now).Error);
        Assert.Equal(OtpErrors.TooManyAttempts, code.Redeem("h", Now).Error);
    }

    [Fact]
    public void Issue_InvalidatesPendingCode()
    {
        var previous = Issue("old");

        var current = VerificationCode.Issue(UserId, OtpPurpose.PasswordReset, "new", previous, Now.AddMinutes(1));

        Assert.False(previous.IsPending);
        Assert.True(current.IsPending);
        Assert.Equal(OtpErrors.InvalidCode, previous.Redeem("old", Now).Error);
    }

    [Fact]
    public void Issue_RejectsPendingCodeOfAnotherPurpose()
    {
        var previous = Issue("old");

        Assert.Throws<ArgumentException>(() =>
            VerificationCode.Issue(UserId, OtpPurpose.AccountActivation, "new", previous, Now));
    }

    [Fact]
    public void GetResendWaitTime_CountsDownToZero()
    {
        var code = Issue("h");

        Assert.Equal(VerificationCode.ResendCooldown, code.GetResendWaitTime(Now));
        Assert.Equal(TimeSpan.Zero, code.GetResendWaitTime(Now + VerificationCode.ResendCooldown));
    }

    private static VerificationCode Issue(string hash) =>
        VerificationCode.Issue(UserId, OtpPurpose.PasswordReset, hash, pendingCode: null, Now);
}

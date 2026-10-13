using Xunit;

namespace Jotter.Domain.UnitTests;

public sealed class SessionTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 12, 8, 0, 0, TimeSpan.Zero);

    [Fact]
    public void UserSession_Revoke_IsIdempotent()
    {
        var session = UserSession.Start(Guid.CreateVersion7(), Now);

        session.Revoke(Now.AddMinutes(1));
        session.Revoke(Now.AddMinutes(2));

        Assert.Equal(Now.AddMinutes(1), session.RevokedAt);
        Assert.False(session.IsActiveAt(Now.AddMinutes(1)));
    }

    [Fact]
    public void NoteUnlockSession_End_ExpiresImmediately()
    {
        var note = Note.Create(Guid.CreateVersion7(), Guid.CreateVersion7(), "a", "b", Now).Value;
        note.EnableProtection(NotePassword.FromHash("hash"));
        var session = note.IssueUnlockSession(note.OwnerId, Now).Value;

        session.End(Now.AddMinutes(1));

        Assert.False(session.IsActiveAt(Now.AddMinutes(1)));
        Assert.Equal(Now.AddMinutes(1), session.ExpiresAt);
    }

    [Fact]
    public void NoteUnlockSession_Extend_SlidesExpiryWhileActive()
    {
        var session = IssueUnlockSession();
        var activity = Now.AddMinutes(10);

        session.Extend(activity);

        Assert.Equal(activity + NoteUnlockSession.Lifetime, session.ExpiresAt);
    }

    [Fact]
    public void NoteUnlockSession_Extend_CannotReviveEndedOrExpiredSession()
    {
        var ended = IssueUnlockSession();
        ended.End(Now.AddMinutes(1));
        ended.Extend(Now.AddMinutes(1));

        var expired = IssueUnlockSession();
        expired.Extend(Now + NoteUnlockSession.Lifetime);

        Assert.Equal(Now.AddMinutes(1), ended.ExpiresAt);
        Assert.Equal(Now + NoteUnlockSession.Lifetime, expired.ExpiresAt);
    }

    [Fact]
    public void PasswordResetTicket_ConsumesOnce_AndExpires()
    {
        var ticket = PasswordResetTicket.Issue(Guid.CreateVersion7(), "hash", Now);

        Assert.Equal(OtpErrors.TicketExpired, ticket.EnsureRedeemable(Now + PasswordResetTicket.Lifetime).Error);
        Assert.True(ticket.Redeem(Now).IsSuccess);
        Assert.Equal(OtpErrors.InvalidResetTicket, ticket.Redeem(Now).Error);
    }

    private static NoteUnlockSession IssueUnlockSession()
    {
        var note = Note.Create(Guid.CreateVersion7(), Guid.CreateVersion7(), "a", "b", Now).Value;
        note.EnableProtection(NotePassword.FromHash("hash"));
        return note.IssueUnlockSession(note.OwnerId, Now).Value;
    }
}

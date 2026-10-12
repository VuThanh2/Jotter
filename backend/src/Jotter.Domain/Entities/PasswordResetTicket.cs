namespace Jotter.Domain;

public sealed class PasswordResetTicket : Entity, IAggregateRoot
{
    public static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(10);

    private PasswordResetTicket()
    {
    }

    private PasswordResetTicket(Guid userId, string ticketHash, DateTimeOffset now)
        : base(Guid.CreateVersion7(now))
    {
        UserId = userId;
        TicketHash = ticketHash;
        ExpiresAt = now + Lifetime;
        CreatedAt = now;
    }

    public Guid UserId { get; private init; }

    public string TicketHash { get; private init; } = string.Empty;

    public DateTimeOffset ExpiresAt { get; private init; }

    public DateTimeOffset? ConsumedAt { get; private set; }

    public DateTimeOffset CreatedAt { get; private init; }

    public static PasswordResetTicket Issue(Guid userId, string ticketHash, DateTimeOffset now)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(ticketHash);
        return new PasswordResetTicket(userId, ticketHash, now);
    }

    // Tách khỏi Redeem để Command kiểm ticket trước, gọi Identity đổi mật khẩu, rồi mới tiêu thụ —
    // mật khẩu mới bị Identity từ chối thì ticket vẫn còn dùng được.
    public Result EnsureRedeemable(DateTimeOffset now)
    {
        if (ConsumedAt is not null)
        {
            return OtpErrors.InvalidResetTicket;
        }

        if (now >= ExpiresAt)
        {
            return OtpErrors.TicketExpired;
        }

        return Result.Success();
    }

    public Result Redeem(DateTimeOffset now)
    {
        var check = EnsureRedeemable(now);
        if (check.IsFailure)
        {
            return check;
        }

        ConsumedAt = now;

        return Result.Success();
    }
}

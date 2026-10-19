namespace Jotter.Domain;

public sealed class UserSession : Entity, IAggregateRoot
{
    public static readonly TimeSpan Lifetime = TimeSpan.FromDays(30);

    private UserSession()
    {
    }

    private UserSession(Guid userId, DateTimeOffset now) : base(Guid.CreateVersion7(now))
    {
        UserId = userId;
        IssuedAt = now;
        ExpiresAt = now + Lifetime;
    }

    public Guid UserId { get; private init; }

    public DateTimeOffset IssuedAt { get; private init; }

    public DateTimeOffset ExpiresAt { get; private init; }

    public DateTimeOffset? RevokedAt { get; private set; }

    public static UserSession Start(Guid userId, DateTimeOffset now) => new(userId, now);

    public bool IsActiveAt(DateTimeOffset now) => RevokedAt is null && now < ExpiresAt;

    public void Revoke(DateTimeOffset now) => RevokedAt ??= now;
}

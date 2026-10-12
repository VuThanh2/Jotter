using System.Security.Cryptography;
using System.Text;

namespace Jotter.Domain;

public sealed class VerificationCode : Entity, IAggregateRoot
{
    public const int MaxAttempts = 5;
    public static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(15);
    public static readonly TimeSpan ResendCooldown = TimeSpan.FromSeconds(60);

    private VerificationCode()
    {
    }

    private VerificationCode(Guid userId, OtpPurpose purpose, string codeHash, DateTimeOffset now)
        : base(Guid.CreateVersion7(now))
    {
        UserId = userId;
        Purpose = purpose;
        CodeHash = codeHash;
        ExpiresAt = now + Lifetime;
        CreatedAt = now;
    }

    public Guid UserId { get; private init; }

    public OtpPurpose Purpose { get; private init; }

    public string CodeHash { get; private init; } = string.Empty;

    public DateTimeOffset ExpiresAt { get; private init; }

    public int AttemptCount { get; private set; }

    public DateTimeOffset? ConsumedAt { get; private set; }

    public DateTimeOffset? InvalidatedAt { get; private set; }

    public DateTimeOffset CreatedAt { get; private init; }

    public bool IsPending => ConsumedAt is null && InvalidatedAt is null;

    // Nhận luôn mã đang chờ (nếu có) để vô hiệu nó: mỗi (userId, purpose) chỉ có tối đa một mã còn sống.
    public static VerificationCode Issue(
        Guid userId,
        OtpPurpose purpose,
        string codeHash,
        VerificationCode? pendingCode,
        DateTimeOffset now)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(codeHash);

        if (pendingCode is not null)
        {
            if (pendingCode.UserId != userId || pendingCode.Purpose != purpose)
            {
                throw new ArgumentException("Mã đang chờ phải cùng userId và purpose.", nameof(pendingCode));
            }

            pendingCode.Invalidate(now);
        }

        return new VerificationCode(userId, purpose, codeHash, now);
    }

    public TimeSpan GetResendWaitTime(DateTimeOffset now)
    {
        var wait = CreatedAt + ResendCooldown - now;
        return wait > TimeSpan.Zero ? wait : TimeSpan.Zero;
    }

    // Nhập sai vẫn làm tăng AttemptCount: Command phải SaveChanges cả khi Result thất bại.
    public Result Redeem(string submittedCodeHash, DateTimeOffset now)
    {
        if (!IsPending)
        {
            return OtpErrors.InvalidCode;
        }

        if (AttemptCount >= MaxAttempts)
        {
            return OtpErrors.TooManyAttempts;
        }

        if (now >= ExpiresAt)
        {
            return OtpErrors.CodeExpired;
        }

        if (!Matches(submittedCodeHash))
        {
            AttemptCount++;
            return AttemptCount >= MaxAttempts ? OtpErrors.TooManyAttempts : OtpErrors.InvalidCode;
        }

        ConsumedAt = now;

        return Result.Success();
    }

    public void Invalidate(DateTimeOffset now)
    {
        if (IsPending)
        {
            InvalidatedAt = now;
        }
    }

    private bool Matches(string submittedCodeHash) =>
        CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(CodeHash),
            Encoding.UTF8.GetBytes(submittedCodeHash));
}

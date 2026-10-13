namespace Jotter.Domain;

public sealed class NoteUnlockSession : Entity, IAggregateRoot
{
    public static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(15);

    private NoteUnlockSession()
    {
    }

    private NoteUnlockSession(Guid noteId, Guid userId, DateTimeOffset now) : base(Guid.CreateVersion7(now))
    {
        NoteId = noteId;
        UserId = userId;
        IssuedAt = now;
        ExpiresAt = now + Lifetime;
    }

    public Guid NoteId { get; private init; }

    public Guid UserId { get; private init; }

    public DateTimeOffset IssuedAt { get; private init; }

    public DateTimeOffset ExpiresAt { get; private set; }

    // Chỉ Note.IssueUnlockSession được gọi, để không thể có phiên mở khoá cho note không được bảo vệ.
    internal static NoteUnlockSession Issue(Guid noteId, Guid userId, DateTimeOffset now) =>
        new(noteId, userId, now);

    public bool IsActiveAt(DateTimeOffset now) => now < ExpiresAt;

    // Hết hạn theo thời gian không thao tác (UC-22). Phiên đã hết hạn hoặc đã bị End thì không gia hạn được,
    // để đổi mật khẩu, tắt bảo vệ và đăng xuất luôn huỷ phiên triệt để.
    public void Extend(DateTimeOffset now)
    {
        if (IsActiveAt(now))
        {
            ExpiresAt = now + Lifetime;
        }
    }

    // Kết thúc bằng cách cho hết hạn ngay: không cần cột revokedAt, tác vụ dọn dẹp xoá theo ExpiresAt.
    public void End(DateTimeOffset now)
    {
        if (IsActiveAt(now))
        {
            ExpiresAt = now;
        }
    }
}

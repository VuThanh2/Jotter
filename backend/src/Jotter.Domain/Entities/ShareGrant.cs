namespace Jotter.Domain;

// "Chỉ chủ sở hữu được chia sẻ", "không cấp trùng" và "người nhận đã đăng ký" là bất biến xuyên Aggregate — Application kiểm trước.
public sealed class ShareGrant : Entity, IAggregateRoot, ISyncTracked
{
    private ShareGrant()
    {
    }

    private ShareGrant(Guid noteId, Guid recipientUserId, SharePermission permission, DateTimeOffset now)
        : base(Guid.CreateVersion7(now))
    {
        NoteId = noteId;
        RecipientUserId = recipientUserId;
        Permission = permission;
        SharedAt = now;
    }

    public Guid NoteId { get; private init; }

    public Guid RecipientUserId { get; private init; }

    public SharePermission Permission { get; private set; }

    public DateTimeOffset SharedAt { get; private init; }

    public DateTimeOffset? RevokedAt { get; private set; }

    public long ChangeSeq { get; private set; }

    public bool IsRevoked => RevokedAt is not null;

    public static Result<ShareGrant> Create(
        Guid noteId,
        Guid noteOwnerId,
        Guid recipientUserId,
        SharePermission permission,
        DateTimeOffset now)
    {
        if (recipientUserId == noteOwnerId)
        {
            return ShareErrors.CannotShareWithSelf;
        }

        if (!Enum.IsDefined(permission))
        {
            return ShareErrors.InvalidPermission;
        }

        return new ShareGrant(noteId, recipientUserId, permission, now);
    }

    public Result ChangePermission(SharePermission permission)
    {
        if (IsRevoked)
        {
            return ShareErrors.NotFound;
        }

        if (!Enum.IsDefined(permission))
        {
            return ShareErrors.InvalidPermission;
        }

        Permission = permission;

        return Result.Success();
    }

    public Result Revoke(DateTimeOffset now)
    {
        if (IsRevoked)
        {
            return ShareErrors.NotFound;
        }

        RevokedAt = now;

        return Result.Success();
    }
}

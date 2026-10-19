using Jotter.Domain;

namespace Jotter.Application;

public sealed record NoteAccess(NoteAccessLevel Level, bool IsProtected, bool HasActiveUnlockSession)
{
    public static readonly NoteAccess None = new(NoteAccessLevel.None, IsProtected: false, HasActiveUnlockSession: false);

    public bool CanView => Level != NoteAccessLevel.None;

    public bool IsOwner => Level == NoteAccessLevel.Owner;

    public bool IsLocked => IsProtected && !HasActiveUnlockSession;

    // Metadata (tiêu đề, version, chỉ báo trạng thái) không cần mở khoá.
    public Result EnsureCanView() => Ensure(NoteAccessLevel.ReadOnly, requireUnlocked: false);

    public Result EnsureCanReadContent() => Ensure(NoteAccessLevel.ReadOnly, requireUnlocked: true);

    public Result EnsureCanEditContent() => Ensure(NoteAccessLevel.Edit, requireUnlocked: true);

    public Result EnsureOwner() => Ensure(NoteAccessLevel.Owner, requireUnlocked: false);

    public Result EnsureUnlockedOwner() => Ensure(NoteAccessLevel.Owner, requireUnlocked: true);

    // Không có quyền gì → 404 để không lộ note có tồn tại; thiếu mức quyền → 403; đủ quyền nhưng đang khoá → 423.
    private Result Ensure(NoteAccessLevel required, bool requireUnlocked)
    {
        if (!CanView)
        {
            return NoteErrors.NotFound;
        }

        if (Level < required)
        {
            return AccessErrors.Forbidden;
        }

        if (requireUnlocked && IsLocked)
        {
            return AccessErrors.NoteLocked;
        }

        return Result.Success();
    }
}

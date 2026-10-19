using Jotter.Domain;

namespace Jotter.Application;

public sealed class ChangeNotePasswordCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    INoteUnlockSessionRepository unlockSessions,
    INotePasswordHasher passwordHasher,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result> ExecuteAsync(Guid noteId, ChangeNotePasswordInputDto input, CancellationToken ct)
    {
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureOwner();
        if (permission.IsFailure)
        {
            return permission;
        }

        var note = await notes.GetByIdAsync(noteId, ct);
        if (note is null)
        {
            return NoteErrors.NotFound;
        }

        if (note.PasswordHash is not { } passwordHash)
        {
            return ProtectionErrors.NotProtected;
        }

        if (!passwordHasher.Verify(passwordHash, input.CurrentPassword))
        {
            return ProtectionErrors.InvalidNotePassword;
        }

        var now = clock.GetUtcNow();
        var activeSessions = await unlockSessions.ListActiveByNoteAsync(noteId, now, ct);

        var changed = note.ChangePassword(passwordHasher.Hash(input.NewPassword));
        if (changed.IsFailure)
        {
            return changed;
        }

        // Huỷ phiên mở khoá trên MỌI thiết bị của mọi người: ai cũng phải mở khoá lại bằng mật khẩu mới.
        foreach (var session in activeSessions)
        {
            session.End(now);
        }

        await unitOfWork.SaveChangesAsync(ct);

        return Result.Success();
    }
}

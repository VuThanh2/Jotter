using Jotter.Domain;

namespace Jotter.Application;

public sealed class DisableProtectionCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    INoteUnlockSessionRepository unlockSessions,
    INotePasswordHasher passwordHasher,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result> ExecuteAsync(Guid noteId, DisableProtectionInputDto input, CancellationToken ct)
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

        // Bắt buộc xác nhận mật khẩu: không được tắt bảo vệ chỉ bằng một thao tác đơn.
        if (!passwordHasher.Verify(passwordHash, input.CurrentPassword))
        {
            return ProtectionErrors.InvalidNotePassword;
        }

        var now = clock.GetUtcNow();
        var activeSessions = await unlockSessions.ListActiveByNoteAsync(noteId, now, ct);

        var disabled = note.DisableProtection();
        if (disabled.IsFailure)
        {
            return disabled;
        }

        foreach (var session in activeSessions)
        {
            session.End(now);
        }

        await unitOfWork.SaveChangesAsync(ct);

        return Result.Success();
    }
}

using Jotter.Domain;

namespace Jotter.Application;

// Người được chia sẻ cũng mở khoá qua đây: chia sẻ note bảo vệ không đồng nghĩa với chia sẻ quyền đọc nội dung.
// Giới hạn số lần thử (TooManyAttempts) do rate limiter của Api đảm nhận, tách hẳn khỏi lockout tài khoản của Identity.
public sealed class UnlockNoteCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    INoteUnlockSessionRepository unlockSessions,
    INotePasswordHasher passwordHasher,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result<UnlockNoteOutputDto>> ExecuteAsync(
        Guid noteId,
        UnlockNoteInputDto input,
        CancellationToken ct)
    {
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureCanView();
        if (permission.IsFailure)
        {
            return permission.Error;
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

        // Đối chiếu ở server; client không bao giờ tự so sánh.
        if (!passwordHasher.Verify(passwordHash, input.Password))
        {
            return ProtectionErrors.InvalidNotePassword;
        }

        var now = clock.GetUtcNow();

        // Mỗi (note, user) chỉ giữ một phiên còn sống để việc kết thúc phiên luôn triệt để.
        var previousSessions = await unlockSessions.ListActiveAsync(noteId, currentUser.UserId, now, ct);

        var issued = note.IssueUnlockSession(currentUser.UserId, now);
        if (issued.IsFailure)
        {
            return issued.Error;
        }

        foreach (var previous in previousSessions)
        {
            previous.End(now);
        }

        unlockSessions.Add(issued.Value);

        await unitOfWork.SaveChangesAsync(ct);

        return new UnlockNoteOutputDto(issued.Value.Id, issued.Value.ExpiresAt);
    }
}

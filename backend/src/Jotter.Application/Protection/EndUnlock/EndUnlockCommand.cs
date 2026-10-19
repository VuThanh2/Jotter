using Jotter.Domain;

namespace Jotter.Application;

// Client gọi khi đóng editor để trả quyền sớm thay vì chờ hết TTL. Idempotent và không cần kiểm quyền
// vì chỉ chạm tới phiên của chính người gọi.
public sealed class EndUnlockCommand(
    ICurrentUser currentUser,
    INoteUnlockSessionRepository unlockSessions,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result> ExecuteAsync(Guid noteId, CancellationToken ct)
    {
        var now = clock.GetUtcNow();

        var activeSessions = await unlockSessions.ListActiveAsync(noteId, currentUser.UserId, now, ct);
        foreach (var session in activeSessions)
        {
            session.End(now);
        }

        await unitOfWork.SaveChangesAsync(ct);

        return Result.Success();
    }
}

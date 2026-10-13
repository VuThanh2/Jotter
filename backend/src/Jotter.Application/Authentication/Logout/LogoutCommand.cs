using Jotter.Domain;

namespace Jotter.Application;

public sealed class LogoutCommand(
    ICurrentUser currentUser,
    IUserSessionRepository sessions,
    INoteUnlockSessionRepository unlockSessions,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result> ExecuteAsync(CancellationToken ct)
    {
        var now = clock.GetUtcNow();

        // Chỉ thu hồi phiên của thiết bị hiện tại. Không xoay securityStamp — làm vậy sẽ đá luôn mọi thiết bị khác.
        var session = await sessions.GetByIdAsync(currentUser.SessionId, ct);
        session?.Revoke(now);

        // Phiên mở khoá là trạng thái ở server: chỉ xoá token phía client thì note vẫn còn mở.
        var activeUnlocks = await unlockSessions.ListActiveByUserAsync(currentUser.UserId, now, ct);
        foreach (var unlock in activeUnlocks)
        {
            unlock.End(now);
        }

        await unitOfWork.SaveChangesAsync(ct);

        return Result.Success();
    }
}

using Jotter.Domain;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class UserSessionRepository(AppDbContext db) : IUserSessionRepository
{
    public Task<UserSession?> GetByIdAsync(Guid sessionId, CancellationToken ct) =>
        db.UserSessions.FirstOrDefaultAsync(s => s.Id == sessionId, ct);

    public void Add(UserSession session) => db.UserSessions.Add(session);
}

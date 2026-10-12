namespace Jotter.Domain;

public interface IUserSessionRepository
{
    Task<UserSession?> GetByIdAsync(Guid sessionId, CancellationToken ct);

    void Add(UserSession session);
}

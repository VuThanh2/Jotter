using Jotter.Application;

namespace Jotter.Infrastructure.IntegrationTests;

// Thay cho CurrentUser đọc từ HttpContext: test đổi người gọi bằng InfrastructureHost.ActAs.
internal sealed class TestCurrentUser : ICurrentUser
{
    public Guid UserId { get; private set; }

    public Guid SessionId { get; private set; }

    public void Set(Guid userId, Guid sessionId)
    {
        UserId = userId;
        SessionId = sessionId;
    }
}

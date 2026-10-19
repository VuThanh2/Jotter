using Jotter.Domain;

namespace Jotter.Application;

public interface ITokenService
{
    // Claim: userId, sessionId, securityStamp. Token hết hạn cùng lúc với session.
    IssuedToken IssueAccessToken(User user, UserSession session);

    // TTL ngắn, mang scope "ws" để mọi endpoint REST từ chối loại token này.
    IssuedToken IssueRealtimeToken(User user, Guid sessionId);
}

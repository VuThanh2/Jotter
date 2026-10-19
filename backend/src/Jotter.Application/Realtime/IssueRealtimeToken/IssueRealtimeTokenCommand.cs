using Jotter.Domain;

namespace Jotter.Application;

// Trình duyệt không gắn được header khi bắt tay WebSocket nên token phải đi qua query string;
// vì vậy cấp riêng token TTL ngắn, chỉ dùng được để mở kết nối, thay vì để access token lọt vào log.
public sealed class IssueRealtimeTokenCommand(ICurrentUser currentUser, IUserRepository users, ITokenService tokens)
{
    public async Task<Result<IssueRealtimeTokenOutputDto>> ExecuteAsync(CancellationToken ct)
    {
        var user = await users.GetByIdAsync(currentUser.UserId, ct);
        if (user is null)
        {
            return UserErrors.NotFound;
        }

        var token = tokens.IssueRealtimeToken(user, currentUser.SessionId);

        return new IssueRealtimeTokenOutputDto(token.Value, token.ExpiresAt);
    }
}

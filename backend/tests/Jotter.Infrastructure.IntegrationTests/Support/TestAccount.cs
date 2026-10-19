using Microsoft.IdentityModel.JsonWebTokens;

namespace Jotter.Infrastructure.IntegrationTests;

// Một thiết bị đã đăng nhập: danh tính lấy thẳng từ claim của token như server đọc ở mỗi request.
internal sealed record TestAccount(Guid UserId, Guid SessionId, string Email, string AccessToken)
{
    public static TestAccount FromToken(string email, string accessToken)
    {
        var token = new JsonWebToken(accessToken);
        return new TestAccount(
            Guid.Parse(token.GetClaim(JotterClaimTypes.UserId).Value),
            Guid.Parse(token.GetClaim(JotterClaimTypes.SessionId).Value),
            email,
            accessToken);
    }
}

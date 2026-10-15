using System.Security.Claims;
using System.Text;
using Jotter.Application;
using Jotter.Domain;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Jotter.Infrastructure;

// Claim chỉ mang thứ bất biến trong vòng đời token; displayName và isActivated đọc từ GET /api/me.
public sealed class JwtTokenService(IOptions<JwtOptions> options, TimeProvider clock) : ITokenService
{
    private readonly JwtOptions _options = options.Value;
    private readonly JsonWebTokenHandler _handler = new();

    public IssuedToken IssueAccessToken(User user, UserSession session) =>
        Issue(user, session.Id, session.ExpiresAt, scope: null);

    public IssuedToken IssueRealtimeToken(User user, Guid sessionId) =>
        Issue(user, sessionId, clock.GetUtcNow() + _options.RealtimeTokenLifetime, JotterClaimTypes.RealtimeScope);

    public static SymmetricSecurityKey CreateSigningKey(JwtOptions options) =>
        new(Encoding.UTF8.GetBytes(options.Secret));

    private IssuedToken Issue(User user, Guid sessionId, DateTimeOffset expiresAt, string? scope)
    {
        var claims = new List<Claim>
        {
            new(JotterClaimTypes.UserId, user.Id.ToString()),
            new(JotterClaimTypes.SessionId, sessionId.ToString()),
            new(JotterClaimTypes.SecurityStamp, user.SecurityStamp ?? string.Empty)
        };

        if (scope is not null)
        {
            claims.Add(new Claim(JotterClaimTypes.Scope, scope));
        }

        var now = clock.GetUtcNow().UtcDateTime;
        var token = _handler.CreateToken(new SecurityTokenDescriptor
        {
            Issuer = _options.Issuer,
            Audience = _options.Audience,
            Subject = new ClaimsIdentity(claims),
            IssuedAt = now,
            NotBefore = now,
            Expires = expiresAt.UtcDateTime,
            SigningCredentials = new SigningCredentials(CreateSigningKey(_options), SecurityAlgorithms.HmacSha256)
        });

        return new IssuedToken(token, expiresAt);
    }
}

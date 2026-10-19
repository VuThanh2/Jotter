using System.Security.Claims;

namespace Jotter.Infrastructure;

// Cách DUY NHẤT đọc claim, dùng chung cho REST (CurrentUser) lẫn WebSocket. JwtBearer đặt MapInboundClaims = false
// nên tên claim lúc đọc trùng đúng tên lúc phát hành, không bị đổi sang tên dài theo chuẩn cũ.
public static class ClaimsPrincipalExtensions
{
    public static Guid GetUserId(this ClaimsPrincipal principal) =>
        principal.GetRequiredGuid(JotterClaimTypes.UserId);

    public static Guid GetSessionId(this ClaimsPrincipal principal) =>
        principal.GetRequiredGuid(JotterClaimTypes.SessionId);

    public static string? GetSecurityStamp(this ClaimsPrincipal principal) =>
        principal.FindFirstValue(JotterClaimTypes.SecurityStamp);

    public static bool HasRealtimeScope(this ClaimsPrincipal principal) =>
        principal.HasClaim(JotterClaimTypes.Scope, JotterClaimTypes.RealtimeScope);

    public static bool TryGetGuid(this ClaimsPrincipal principal, string claimType, out Guid value) =>
        Guid.TryParse(principal.FindFirstValue(claimType), out value);

    private static Guid GetRequiredGuid(this ClaimsPrincipal principal, string claimType) =>
        principal.TryGetGuid(claimType, out var value)
            ? value
            : throw new InvalidOperationException($"Principal không có claim '{claimType}' hợp lệ.");
}

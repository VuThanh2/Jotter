using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

// Đối chiếu mỗi request với DB, KHÔNG cache: token sống 30 ngày nên cache chính là độ trễ thu hồi.
// sessionId thu hồi đúng một thiết bị (đăng xuất); securityStamp thu hồi mọi thiết bị (đổi/đặt lại mật khẩu).
public sealed class SessionValidator(AppDbContext db, TimeProvider clock)
{
    public async Task ValidateAsync(TokenValidatedContext context)
    {
        var principal = context.Principal;
        var isValid = principal is not null
            && principal.TryGetGuid(JotterClaimTypes.UserId, out var userId)
            && principal.TryGetGuid(JotterClaimTypes.SessionId, out var sessionId)
            && principal.GetSecurityStamp() is { } securityStamp
            && await IsActiveAsync(userId, sessionId, securityStamp, context.HttpContext.RequestAborted);

        if (!isValid)
        {
            context.Fail("Phiên đăng nhập đã bị thu hồi hoặc hết hạn.");
        }
    }

    // Một truy vấn duy nhất: phiên còn sống và stamp của tài khoản chưa bị xoay.
    public Task<bool> IsActiveAsync(Guid userId, Guid sessionId, string securityStamp, CancellationToken ct)
    {
        var now = clock.GetUtcNow();

        return db.UserSessions
            .Where(s => s.Id == sessionId && s.UserId == userId && s.RevokedAt == null && s.ExpiresAt > now)
            .Join(db.Users, s => s.UserId, u => u.Id, (_, u) => u.SecurityStamp)
            .AnyAsync(stamp => stamp == securityStamp, ct);
    }
}

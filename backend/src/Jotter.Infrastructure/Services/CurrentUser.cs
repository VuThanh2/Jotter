using System.Security.Claims;
using Jotter.Application;
using Microsoft.AspNetCore.Http;

namespace Jotter.Infrastructure;

// Chỉ dùng trong request đã xác thực; thiếu claim là lỗi lập trình (endpoint quên yêu cầu đăng nhập).
public sealed class CurrentUser(IHttpContextAccessor httpContextAccessor) : ICurrentUser
{
    public Guid UserId => Principal.GetUserId();

    public Guid SessionId => Principal.GetSessionId();

    private ClaimsPrincipal Principal =>
        httpContextAccessor.HttpContext?.User
        ?? throw new InvalidOperationException("ICurrentUser chỉ dùng được bên trong một HTTP request.");
}

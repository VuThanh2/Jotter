using Microsoft.AspNetCore.Authorization;

namespace Jotter.Infrastructure;

// Token "ws" đi qua query string nên dễ lọt vào log proxy; nếu REST nhận nó thì việc giới hạn phạm vi chỉ còn hình thức.
public sealed class RestScopeAuthorizationHandler : AuthorizationHandler<RestScopeRequirement>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        RestScopeRequirement requirement)
    {
        if (!context.User.HasRealtimeScope())
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}

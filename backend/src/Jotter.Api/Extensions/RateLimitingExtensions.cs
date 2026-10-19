using System.Globalization;
using System.Threading.RateLimiting;
using Jotter.Application;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace Jotter.Api;

public static class RateLimitingExtensions
{
    public static IServiceCollection AddApiRateLimiting(this IServiceCollection services)
    {
        services
            .AddOptions<RateLimitOptions>()
            .BindConfiguration(RateLimitOptions.SectionName)
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.OnRejected = OnRejectedAsync;
        });

        services
            .AddOptions<RateLimiterOptions>()
            .Configure<IOptions<RateLimitOptions>>((limiter, limits) =>
            {
                var rules = limits.Value;

                limiter.AddPolicy(RateLimitPolicies.Auth, context => FixedWindow(CallerKey(context), rules.Auth));
                limiter.AddPolicy(RateLimitPolicies.OtpSend, context => FixedWindow(CallerKey(context), rules.OtpSend));
                limiter.AddPolicy(RateLimitPolicies.OtpVerify, context => FixedWindow(CallerKey(context), rules.OtpVerify));
                limiter.AddPolicy(RateLimitPolicies.Llm, context => FixedWindow(CallerKey(context), rules.Llm));
                limiter.AddPolicy(RateLimitPolicies.NoteUnlock, context =>
                    FixedWindow($"{CallerKey(context)}:{context.Request.RouteValues["noteId"]}", rules.NoteUnlock));
            });

        return services;
    }

    private static RateLimitPartition<string> FixedWindow(string key, RateLimitRule rule) =>
        RateLimitPartition.GetFixedWindowLimiter(key, _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = rule.PermitLimit,
            Window = rule.Window,
            QueueLimit = 0
        });

    // Đã đăng nhập thì tính theo tài khoản (nhiều thiết bị chung một hạn mức); endpoint công khai thì theo IP.
    // Rate limiter đứng sau UseAuthorization nên token hỏng đã bị chặn 401 từ trước, không ăn vào hạn mức.
    private static string CallerKey(HttpContext context) =>
        context.User.Identity?.IsAuthenticated == true
            ? $"user:{context.RequestServices.GetRequiredService<ICurrentUser>().UserId}"
            : $"ip:{context.Connection.RemoteIpAddress}";

    private static async ValueTask OnRejectedAsync(OnRejectedContext context, CancellationToken ct)
    {
        var httpContext = context.HttpContext;

        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
        {
            httpContext.Response.Headers.RetryAfter =
                ((int)Math.Ceiling(retryAfter.TotalSeconds)).ToString(CultureInfo.InvariantCulture);
        }

        var policy = httpContext.GetEndpoint()?.Metadata.GetMetadata<EnableRateLimitingAttribute>()?.PolicyName;
        await httpContext.WriteProblemAsync(RateLimitPolicies.RejectionErrorOf(policy));
    }
}

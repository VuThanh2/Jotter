using Jotter.Infrastructure;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Jotter.Api;

public static class HealthCheckExtensions
{
    private const string ReadinessTag = "ready";

    public static IServiceCollection AddApiHealthChecks(this IServiceCollection services, IConfiguration configuration)
    {
        var llm = configuration.GetSection(LlmOptions.SectionName).Get<LlmOptions>() ?? new LlmOptions();

        services
            .AddHealthChecks()
            .AddDbContextCheck<AppDbContext>("postgres", tags: [ReadinessTag])
            .AddCheck<StorageHealthCheck>("storage", tags: [ReadinessTag])
            // Thiếu khoá AI thì chỉ tính năng AI trả 503, phần còn lại vẫn chạy: Degraded chứ không Unhealthy.
            // Không gọi thử provider để mỗi lần kiểm không tốn hạn mức.
            .AddCheck(
                "llm",
                () => llm is { IsChatConfigured: true, IsEmbeddingConfigured: true }
                    ? HealthCheckResult.Healthy()
                    : HealthCheckResult.Degraded("Chưa cấu hình khoá API cho LLM hoặc embedding."),
                tags: [ReadinessTag]);

        return services;
    }

    // Liveness không chạm DB để không báo chết oan khi DB tạm chậm; readiness kiểm từng tầng để chẩn đoán nhanh.
    public static IEndpointRouteBuilder MapApiHealthChecks(this IEndpointRouteBuilder endpoints)
    {
        endpoints
            .MapHealthChecks("/health", new HealthCheckOptions
            {
                Predicate = _ => false,
                ResponseWriter = HealthCheckResponseWriter.WriteAsync
            })
            .AllowAnonymous();

        endpoints
            .MapHealthChecks("/health/ready", new HealthCheckOptions
            {
                Predicate = check => check.Tags.Contains(ReadinessTag),
                ResponseWriter = HealthCheckResponseWriter.WriteAsync
            })
            .AllowAnonymous();

        return endpoints;
    }
}

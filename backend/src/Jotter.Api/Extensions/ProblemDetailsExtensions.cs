using System.Diagnostics;
using System.Globalization;
using Jotter.Domain;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.Net.Http.Headers;

namespace Jotter.Api;

// Writer DUY NHẤT cho mọi lỗi trả ra client — Result của use case, validation, 401/403 của JwtBearer, 429, exception —
// để response lỗi luôn có cùng hình dạng RFC 7807 kèm `code` ổn định và `traceId`.
public static class ProblemDetailsExtensions
{
    private const string ContentType = "application/problem+json";

    // Lỗi nghiệp vụ báo thời gian chờ qua chi tiết này (vd. gửi lại mã quá sớm).
    private const string CooldownSecondsDetail = "cooldownSeconds";

    public static Task WriteProblemAsync(this HttpContext httpContext, Error error, int? statusCode = null)
    {
        var problem = httpContext.CreateProblemDetails(error, statusCode ?? ToStatusCode(error.Type));
        var json = httpContext.RequestServices.GetRequiredService<IOptions<JsonOptions>>().Value.JsonSerializerOptions;

        httpContext.Response.StatusCode = problem.Status!.Value;

        // Mọi 429 đều mang Retry-After như 429 của rate limiter, để client chỉ cần đọc một chỗ.
        // Rate limiter đã tự ghi header theo lease của nó thì giữ nguyên.
        if (problem.Status == StatusCodes.Status429TooManyRequests
            && error.Details?.GetValueOrDefault(CooldownSecondsDetail) is int cooldownSeconds
            && !httpContext.Response.Headers.ContainsKey(HeaderNames.RetryAfter))
        {
            httpContext.Response.Headers.RetryAfter = cooldownSeconds.ToString(CultureInfo.InvariantCulture);
        }

        return httpContext.Response.WriteAsJsonAsync(problem, json, ContentType, httpContext.RequestAborted);
    }

    private static ProblemDetails CreateProblemDetails(this HttpContext httpContext, Error error, int statusCode)
    {
        var problem = new ProblemDetails { Status = statusCode, Title = error.Message };

        if (error.Details is not null)
        {
            foreach (var (key, value) in error.Details)
            {
                problem.Extensions[key] = value;
            }
        }

        // Ghi sau Details để không chi tiết nào đè được hai trường client dựa vào.
        problem.Extensions["code"] = error.Code;
        problem.Extensions["traceId"] = Activity.Current?.Id ?? httpContext.TraceIdentifier;

        return problem;
    }

    private static int ToStatusCode(ErrorType type) => type switch
    {
        ErrorType.Validation => StatusCodes.Status400BadRequest,
        ErrorType.Unauthorized => StatusCodes.Status401Unauthorized,
        ErrorType.Forbidden => StatusCodes.Status403Forbidden,
        ErrorType.NotFound => StatusCodes.Status404NotFound,
        ErrorType.Conflict => StatusCodes.Status409Conflict,
        ErrorType.Locked => StatusCodes.Status423Locked,
        ErrorType.TooManyRequests => StatusCodes.Status429TooManyRequests,
        ErrorType.Unavailable => StatusCodes.Status503ServiceUnavailable,
        _ => throw new ArgumentOutOfRangeException(nameof(type), type, "ErrorType chưa được ánh xạ sang mã HTTP.")
    };
}

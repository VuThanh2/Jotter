using System.Text.Json;
using Jotter.Application;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.Extensions.Options;

namespace Jotter.Api;

// Request tới nơi nhưng response rớt giữa đường là chuyện thường trên mạng di động; không có filter này thì outbox
// gửi lại PUT cùng baseVersion sẽ dính 409 và sinh Conflict Copy giả từ chính dữ liệu của người dùng.
// Header là tuỳ chọn: thiếu header thì action chạy như bình thường.
public sealed class IdempotencyFilter(
    IIdempotencyStore store,
    ICurrentUser currentUser,
    IOptions<JsonOptions> jsonOptions) : IAsyncActionFilter
{
    public const string KeyHeader = "Idempotency-Key";
    public const string ReplayHeader = "Idempotent-Replay";

    private const string JsonContentType = "application/json; charset=utf-8";

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var httpContext = context.HttpContext;
        var header = httpContext.Request.Headers[KeyHeader].ToString();
        if (header.Length == 0)
        {
            await next();
            return;
        }

        if (!Guid.TryParse(header, out var operationId))
        {
            context.Result = ApiErrors.InvalidIdempotencyKey.ToActionResult();
            return;
        }

        var ct = httpContext.RequestAborted;
        var stored = await store.FindAsync(currentUser.UserId, operationId, ct);
        if (stored is not null)
        {
            context.Result = new StoredResponseResult(stored, IsReplay: true);
            return;
        }

        // Dispose khi chưa Complete là rollback: exception hay lỗi nghiệp vụ đều không để lại gì.
        await using var scope = await store.BeginAsync(currentUser.UserId, operationId, ct);

        var executed = await next();

        // Chỉ ghi nhận thao tác thành công. Lỗi (423 khi note còn khoá, 403...) không được đóng băng thành response
        // vĩnh viễn — lần gửi lại sau khi tình huống đã đổi phải được thực thi thật.
        if (executed.Exception is not null || !IsSuccess(executed.Result))
        {
            return;
        }

        var response = Capture(executed.Result!);
        await scope.CompleteAsync(response, ct);

        // Lần đầu và lần phát lại ra cùng một chuỗi byte.
        executed.Result = new StoredResponseResult(response, IsReplay: false);
    }

    private static bool IsSuccess(IActionResult? result) =>
        result is IStatusCodeActionResult { StatusCode: >= 200 and < 300 };

    private IdempotentResponse Capture(IActionResult result) => result switch
    {
        ObjectResult { Value: { } value, StatusCode: { } statusCode } => new IdempotentResponse(
            statusCode,
            JsonContentType,
            JsonSerializer.SerializeToUtf8Bytes(value, value.GetType(), jsonOptions.Value.JsonSerializerOptions)),
        IStatusCodeActionResult { StatusCode: { } statusCode } => new IdempotentResponse(statusCode, null, []),
        _ => throw new InvalidOperationException(
            $"[Idempotent] chỉ hỗ trợ response JSON hoặc không có thân, nhận được {result.GetType().Name}.")
    };

    private sealed record StoredResponseResult(IdempotentResponse Response, bool IsReplay) : IActionResult
    {
        public async Task ExecuteResultAsync(ActionContext context)
        {
            var httpResponse = context.HttpContext.Response;
            httpResponse.StatusCode = Response.StatusCode;

            if (IsReplay)
            {
                httpResponse.Headers[ReplayHeader] = "true";
            }

            if (Response.ContentType is not null)
            {
                httpResponse.ContentType = Response.ContentType;
            }

            if (Response.Body.Length > 0)
            {
                httpResponse.ContentLength = Response.Body.Length;
                await httpResponse.Body.WriteAsync(Response.Body, context.HttpContext.RequestAborted);
            }
        }
    }
}

using Jotter.Domain;

namespace Jotter.Api;

// Lỗi nghiệp vụ đi bằng Result; tới được đây chỉ còn lỗi lập trình hoặc lỗi hạ tầng → 500 ProblemDetails kèm traceId,
// không bao giờ lộ stack trace hay thông điệp nội bộ ra client.
// Response đã bắt đầu (giữa luồng SSE hay tệp) thì không đổi được mã HTTP nữa: exception đi tiếp để Kestrel cắt kết nối.
public sealed class GlobalExceptionHandlerMiddleware(
    RequestDelegate next,
    ILogger<GlobalExceptionHandlerMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            // Client chủ động huỷ (đóng app, bấm huỷ tóm tắt AI): không còn ai nhận phản hồi.
            logger.LogDebug("Client đã huỷ {Method} {Path}.", context.Request.Method, context.Request.Path);
        }
        catch (BadHttpRequestException ex) when (!context.Response.HasStarted)
        {
            // Kestrel từ chối request hỏng hoặc vượt giới hạn kích thước — lỗi phía client, không phải sự cố.
            logger.LogInformation(ex, "Request không hợp lệ {Method} {Path}.", context.Request.Method, context.Request.Path);
            await ReplaceResponseAsync(context, ApiErrors.ForStatusCode(ex.StatusCode), ex.StatusCode);
        }
        catch (Exception ex) when (!context.Response.HasStarted)
        {
            logger.LogError(ex, "Lỗi chưa xử lý khi phục vụ {Method} {Path}.", context.Request.Method, context.Request.Path);
            await ReplaceResponseAsync(context, ApiErrors.InternalError, StatusCodes.Status500InternalServerError);
        }
    }

    // Bỏ mọi header đã đặt dở (Content-Disposition, Content-Type...) trước khi ghi lỗi.
    private static Task ReplaceResponseAsync(HttpContext context, Error error, int statusCode)
    {
        context.Response.Clear();
        return context.WriteProblemAsync(error, statusCode);
    }
}

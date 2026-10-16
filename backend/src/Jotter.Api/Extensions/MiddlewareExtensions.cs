using Jotter.Infrastructure;

namespace Jotter.Api;

public static class MiddlewareExtensions
{
    // Thứ tự có chủ đích — đổi chỗ là đổi hành vi:
    // forwarded headers trước mọi thứ đọc IP; exception handler bọc ngoài cùng; status code pages biến 401/403/404
    // rỗng thành ProblemDetails; CORS trước xác thực để preflight không bị đòi token; rate limiter sau phân quyền
    // để request không hợp lệ không ăn vào hạn mức và partition theo tài khoản đọc được người dùng.
    public static WebApplication UsePresentation(this WebApplication app)
    {
        app.UseForwardedHeaders();
        app.UseMiddleware<GlobalExceptionHandlerMiddleware>();
        app.UseStatusCodePages(context =>
        {
            var statusCode = context.HttpContext.Response.StatusCode;
            return context.HttpContext.WriteProblemAsync(ApiErrors.ForStatusCode(statusCode), statusCode);
        });

        // Tệp người dùng tải lên được phục vụ lại nguyên trạng: không cho trình duyệt đoán lại kiểu nội dung.
        app.Use((context, next) =>
        {
            context.Response.Headers.XContentTypeOptions = "nosniff";
            return next(context);
        });

        app.UseApiDocumentation();

        app.UseRouting();
        app.UseCors();
        app.UseAuthentication();
        app.UseAuthorization();
        app.UseRateLimiter();

        // Ping ở tầng giao thức giữ kết nối sống qua proxy (thường cắt kết nối idle ~60 giây) kể cả khi client im lặng.
        app.UseWebSockets(new WebSocketOptions { KeepAliveInterval = TimeSpan.FromSeconds(30) });

        return app;
    }

    public static WebApplication MapPresentation(this WebApplication app)
    {
        app.MapControllers();
        app.MapApiHealthChecks();

        // Bắt tay WebSocket không gắn được header nên dùng token scope "ws" qua query string; policy riêng chỉ nhận
        // đúng loại token đó, ngược với REST.
        app.Map(WebSocketHandler.Path, (HttpContext context, WebSocketHandler handler) => handler.HandleAsync(context))
            .RequireAuthorization(WebSocketHandler.AuthorizationPolicy)
            .ExcludeFromDescription();

        return app;
    }
}

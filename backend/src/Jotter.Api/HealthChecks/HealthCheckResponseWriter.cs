using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Jotter.Api;

// Chỉ trả trạng thái từng thành phần, không kèm thông điệp lỗi: endpoint công khai không được lộ chi tiết hạ tầng
// (chuỗi kết nối, đường dẫn volume). Chi tiết nằm trong log của server.
public static class HealthCheckResponseWriter
{
    public static Task WriteAsync(HttpContext context, HealthReport report)
    {
        var status = report.Status.ToString();

        object body = report.Entries.Count == 0
            ? new { status }
            : new { status, checks = report.Entries.ToDictionary(entry => entry.Key, entry => entry.Value.Status.ToString()) };

        return context.Response.WriteAsJsonAsync(body, context.RequestAborted);
    }
}

using Microsoft.Extensions.Logging;

namespace Jotter.Infrastructure;

// Chỉ dùng khi chưa cấu hình SMTP: mã kích hoạt / đặt lại mật khẩu hiện trong log để vẫn thử được trọn luồng.
public sealed class LoggingEmailTransport(ILogger<LoggingEmailTransport> logger) : IEmailTransport
{
    public Task SendAsync(EmailMessage message, CancellationToken ct)
    {
        logger.LogWarning(
            "SMTP chưa được cấu hình — email tới {ToAddress} chỉ được ghi log.\nTiêu đề: {Subject}\n{TextBody}",
            message.ToAddress,
            message.Subject,
            message.TextBody);

        return Task.CompletedTask;
    }
}

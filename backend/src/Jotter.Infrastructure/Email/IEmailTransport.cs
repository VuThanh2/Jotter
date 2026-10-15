namespace Jotter.Infrastructure;

// Strategy: MailKit khi đã cấu hình SMTP, ghi log khi chưa (chạy thử bằng docker compose mà không cần tài khoản email).
public interface IEmailTransport
{
    Task SendAsync(EmailMessage message, CancellationToken ct);
}

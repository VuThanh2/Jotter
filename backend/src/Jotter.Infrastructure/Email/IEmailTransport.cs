namespace Jotter.Infrastructure;

// Strategy: Mailjet (HTTPS) khi có khoá API — cho Railway vốn chặn SMTP; MailKit khi đã cấu hình SMTP;
// ghi log khi chưa có gì (chạy thử bằng docker compose mà không cần tài khoản email).
public interface IEmailTransport
{
    Task SendAsync(EmailMessage message, CancellationToken ct);
}

using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace Jotter.Infrastructure;

// ASP.NET Core không có SMTP sender dựng sẵn, còn System.Net.Mail.SmtpClient đã bị khuyến cáo không dùng cho code mới.
// Chỉ được tạo khi EmailOptions.IsSmtpConfigured, và EmailOptions đã kiểm đủ địa chỉ người gửi lúc khởi động.
public sealed class MailKitEmailTransport : IEmailTransport
{
    private readonly EmailOptions _options;
    private readonly string _host;
    private readonly string _senderAddress;

    public MailKitEmailTransport(IOptions<EmailOptions> options)
    {
        _options = options.Value;
        _host = _options.Host ?? throw new InvalidOperationException("Thiếu Email:Host.");
        _senderAddress = _options.SenderAddress ?? throw new InvalidOperationException("Thiếu Email:From.");
    }

    public async Task SendAsync(EmailMessage message, CancellationToken ct)
    {
        var mime = new MimeMessage();
        mime.From.Add(new MailboxAddress(_options.FromName, _senderAddress));
        mime.To.Add(new MailboxAddress(message.ToName, message.ToAddress));
        mime.Subject = message.Subject;
        mime.Body = new BodyBuilder { HtmlBody = message.HtmlBody, TextBody = message.TextBody }.ToMessageBody();

        using var client = new SmtpClient();
        await client.ConnectAsync(_host, _options.Port, SecureSocketOptions.Auto, ct);

        if (!string.IsNullOrEmpty(_options.Username))
        {
            await client.AuthenticateAsync(_options.Username, _options.Password ?? string.Empty, ct);
        }

        await client.SendAsync(mime, ct);
        await client.DisconnectAsync(quit: true, ct);
    }
}

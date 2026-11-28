using System.ComponentModel.DataAnnotations;

namespace Jotter.Infrastructure;

public sealed class EmailOptions : IValidatableObject
{
    public const string SectionName = "Email";

    // Để trống thì thư chỉ được ghi ra log — đủ để chạy docker compose mà chưa có tài khoản SMTP.
    public string? Host { get; init; }

    [Range(1, 65535)]
    public int Port { get; init; } = 587;

    public string? Username { get; init; }

    public string? Password { get; init; }

    public string? From { get; init; }

    public string FromName { get; init; } = "Jotter";

    // Chỉ đặt trên Railway (chặn cổng SMTP): có đủ cặp khoá thì gửi qua HTTPS API của Mailjet, được ưu tiên hơn SMTP.
    public string? MailjetApiKey { get; init; }

    public string? MailjetSecretKey { get; init; }

    public bool IsMailjetConfigured =>
        !string.IsNullOrWhiteSpace(MailjetApiKey) && !string.IsNullOrWhiteSpace(MailjetSecretKey);

    public bool IsSmtpConfigured => !string.IsNullOrWhiteSpace(Host);

    public string? SenderAddress => string.IsNullOrWhiteSpace(From) ? Username : From;

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        // Biến môi trường để trống (Email__From=) là chuỗi rỗng, nên chỉ kiểm định dạng khi thật sự có giá trị.
        if (!string.IsNullOrWhiteSpace(From) && !new EmailAddressAttribute().IsValid(From))
        {
            yield return new ValidationResult("Email:From không phải địa chỉ email hợp lệ.", [nameof(From)]);
        }

        if ((IsSmtpConfigured || IsMailjetConfigured) && string.IsNullOrWhiteSpace(SenderAddress))
        {
            yield return new ValidationResult(
                "Cần Email:From (hoặc Email:Username) khi đã cấu hình SMTP hoặc Mailjet.",
                [nameof(From)]);
        }

        // Chỉ đặt một trong hai khoá thì lặng lẽ rơi về SMTP/log — báo ngay lúc khởi động để không tưởng là đã gửi được.
        if (string.IsNullOrWhiteSpace(MailjetApiKey) != string.IsNullOrWhiteSpace(MailjetSecretKey))
        {
            yield return new ValidationResult(
                "Cần đặt cả Email:MailjetApiKey lẫn Email:MailjetSecretKey.",
                [nameof(MailjetApiKey), nameof(MailjetSecretKey)]);
        }
    }
}

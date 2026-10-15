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

    public bool IsSmtpConfigured => !string.IsNullOrWhiteSpace(Host);

    public string? SenderAddress => string.IsNullOrWhiteSpace(From) ? Username : From;

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        // Biến môi trường để trống (Email__From=) là chuỗi rỗng, nên chỉ kiểm định dạng khi thật sự có giá trị.
        if (!string.IsNullOrWhiteSpace(From) && !new EmailAddressAttribute().IsValid(From))
        {
            yield return new ValidationResult("Email:From không phải địa chỉ email hợp lệ.", [nameof(From)]);
        }

        if (IsSmtpConfigured && string.IsNullOrWhiteSpace(SenderAddress))
        {
            yield return new ValidationResult(
                "Cần Email:From (hoặc Email:Username) khi đã cấu hình SMTP.",
                [nameof(From)]);
        }
    }
}

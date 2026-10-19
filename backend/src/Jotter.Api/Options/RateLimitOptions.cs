using System.ComponentModel.DataAnnotations;

namespace Jotter.Api;

// 429 cho: đăng nhập/đăng ký, gửi lại mã, nhập mã, mở khoá note và gọi LLM. Mỗi nhóm một cửa sổ riêng.
public sealed class RateLimitOptions : IValidatableObject
{
    public const string SectionName = "RateLimit";

    public RateLimitRule Auth { get; init; } = new() { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) };

    public RateLimitRule OtpSend { get; init; } = new() { PermitLimit = 5, Window = TimeSpan.FromMinutes(15) };

    public RateLimitRule OtpVerify { get; init; } = new() { PermitLimit = 10, Window = TimeSpan.FromMinutes(15) };

    // Tính theo từng (người dùng, note): mở/đóng nhiều note khác nhau không làm cạn hạn mức của nhau.
    public RateLimitRule NoteUnlock { get; init; } = new() { PermitLimit = 10, Window = TimeSpan.FromMinutes(5) };

    public RateLimitRule Llm { get; init; } = new() { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) };

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        (string Name, RateLimitRule Rule)[] rules =
        [
            (nameof(Auth), Auth),
            (nameof(OtpSend), OtpSend),
            (nameof(OtpVerify), OtpVerify),
            (nameof(NoteUnlock), NoteUnlock),
            (nameof(Llm), Llm)
        ];

        foreach (var (name, _) in rules.Where(entry => !entry.Rule.IsValid))
        {
            yield return new ValidationResult(
                $"RateLimit:{name} cần PermitLimit > 0 và Window > 0.",
                [name]);
        }
    }
}

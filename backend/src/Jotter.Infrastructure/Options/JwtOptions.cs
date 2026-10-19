using System.ComponentModel.DataAnnotations;

namespace Jotter.Infrastructure;

public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    [Required]
    public string Issuer { get; init; } = string.Empty;

    [Required]
    public string Audience { get; init; } = string.Empty;

    // HMAC-SHA256 cần khoá tối thiểu 256 bit.
    [Required]
    [MinLength(32)]
    public string Secret { get; init; } = string.Empty;

    public TimeSpan RealtimeTokenLifetime { get; init; } = TimeSpan.FromMinutes(5);
}

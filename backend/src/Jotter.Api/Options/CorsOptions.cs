using System.ComponentModel.DataAnnotations;

namespace Jotter.Api;

public sealed class CorsOptions : IValidatableObject
{
    public const string SectionName = "Cors";

    // Cho phép "*" vì xác thực bằng Bearer token trong header chứ không bằng cookie: trình duyệt không tự gắn token,
    // nên mở origin không tạo ra rủi ro CSRF.
    private const string AnyOrigin = "*";

    // Để trống thì không mở CORS: app native không cần, chỉ bản web Flutter chạy khác origin mới cần.
    public string[] AllowedOrigins { get; init; } = [];

    public bool AllowsAnyOrigin => AllowedOrigins.Contains(AnyOrigin);

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        foreach (var origin in AllowedOrigins.Where(origin => origin != AnyOrigin && !IsOrigin(origin)))
        {
            yield return new ValidationResult(
                $"Cors:AllowedOrigins chứa '{origin}' không phải origin hợp lệ (dạng https://host[:port]).",
                [nameof(AllowedOrigins)]);
        }
    }

    private static bool IsOrigin(string value) =>
        Uri.TryCreate(value, UriKind.Absolute, out var uri)
        && (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps)
        && uri.PathAndQuery == "/"
        && !value.EndsWith('/');
}

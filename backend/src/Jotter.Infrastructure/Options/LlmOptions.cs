using System.ComponentModel.DataAnnotations;

namespace Jotter.Infrastructure;

// Không bắt buộc khoá API: thiếu thì tính năng AI trả LlmUnavailable thay vì chặn cả ứng dụng khởi động.
public sealed class LlmOptions
{
    public const string SectionName = "Llm";

    public string? ApiKey { get; init; }

    // Tóm tắt một note và trả lời trên vài đoạn trích là việc nhẹ, nên mặc định dùng Haiku cho rẻ.
    // Muốn chất lượng cao hơn thì đổi sang claude-sonnet-5-5 hoặc claude-opus-5-5, không phải sửa code.
    [Required]
    public string Model { get; init; } = "claude-haiku-5-5";

    [Required]
    [RegularExpression("^(low|medium|high|xhigh|max)$")]
    public string Effort { get; init; } = "medium";

    [Range(1024, 128_000)]
    public int MaxTokens { get; init; } = 16_000;

    public string? EmbeddingApiKey { get; init; }

    [Required]
    public string EmbeddingModel { get; init; } = "voyage-4";

    [Required]
    [Url]
    public string EmbeddingBaseUrl { get; init; } = "https://api.voyageai.com/v1/";

    public TimeSpan RequestTimeout { get; init; } = TimeSpan.FromMinutes(2);

    public TimeSpan IndexingInterval { get; init; } = TimeSpan.FromMinutes(1);

    public bool IsChatConfigured => !string.IsNullOrWhiteSpace(ApiKey);

    public bool IsEmbeddingConfigured => !string.IsNullOrWhiteSpace(EmbeddingApiKey);

    // Dòng Haiku không có model dự phòng phía server: gửi kèm fallbacks chỉ vô ích (hoặc 400 với dạng danh sách).
    public bool SupportsServerSideFallback => !Model.StartsWith("claude-haiku-", StringComparison.Ordinal);
}

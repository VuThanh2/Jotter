using System.ComponentModel.DataAnnotations;

namespace Jotter.Infrastructure;

// Không bắt buộc khoá API: thiếu thì tính năng AI trả LlmUnavailable thay vì chặn cả ứng dụng khởi động.
// Một khoá Gemini (aistudio.google.com) dùng chung cho cả sinh văn bản lẫn embedding.
public sealed class LlmOptions
{
    public const string SectionName = "Llm";

    public string? ApiKey { get; init; }

    // Flash-Lite ổn định, có trong free tier: trả lời trong vài giây, trong khi gemini-3.8-flash ở free tier
    // thường mất 20–60 giây và hay trả 503 quá tải. Tóm tắt và hỏi đáp trên vài đoạn trích không cần model lớn hơn.
    [Required]
    public string Model { get; init; } = "gemini-3.5-flash-lite";

    // Tóm tắt một note và trả lời trên vài đoạn trích là việc nhẹ; token suy nghĩ cũng bị tính vào hạn mức free tier.
    [Required]
    [RegularExpression("^(low|medium|high)$")]
    public string ThinkingLevel { get; init; } = "low";

    // Gồm cả token suy nghĩ, nên không đặt quá sát độ dài câu trả lời mong muốn.
    [Range(1024, 65_536)]
    public int MaxOutputTokens { get; init; } = 8_192;

    [Required]
    public string EmbeddingModel { get; init; } = "gemini-embedding-2";

    // 768 là mức Google khuyến nghị và được model tự chuẩn hoá; đổi giá trị này thì phải lập chỉ mục lại toàn bộ.
    [Range(128, 3_072)]
    public int EmbeddingDimensions { get; init; } = 768;

    public TimeSpan RequestTimeout { get; init; } = TimeSpan.FromMinutes(2);

    public TimeSpan IndexingInterval { get; init; } = TimeSpan.FromMinutes(1);

    public bool IsConfigured => !string.IsNullOrWhiteSpace(ApiKey);
}

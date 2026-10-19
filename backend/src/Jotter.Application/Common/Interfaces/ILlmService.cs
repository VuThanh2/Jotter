namespace Jotter.Application;

// Mọi method ném LlmException khi provider lỗi, quá tải hoặc hết hạn mức.
public interface ILlmService
{
    IAsyncEnumerable<string> SummarizeAsync(string title, string content, CancellationToken ct);

    // Trả đúng một vector cho mỗi text, cùng thứ tự với đầu vào.
    Task<IReadOnlyList<float[]>> EmbedAsync(IReadOnlyList<string> texts, CancellationToken ct);

    // Chỉ được trả lời dựa trên passages; không đủ căn cứ thì HasEnoughContext = false thay vì bịa.
    Task<LlmAnswer> AnswerAsync(string question, IReadOnlyList<ContextPassage> passages, CancellationToken ct);
}

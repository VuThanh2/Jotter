using System.Runtime.CompilerServices;
using Jotter.Application;

namespace Jotter.Api.IntegrationTests;

// Thay provider thật để kiểm luồng SSE mà không cần khoá API hay mạng. Chỉ tóm tắt là có dùng trong test.
public sealed class FakeLlmService : ILlmService
{
    public static readonly string[] SummaryChunks = ["Tóm tắt: ", "kế hoạch bốn tuần."];

    public async IAsyncEnumerable<string> SummarizeAsync(
        string title,
        string content,
        [EnumeratorCancellation] CancellationToken ct)
    {
        foreach (var chunk in SummaryChunks)
        {
            await Task.Yield();
            yield return chunk;
        }
    }

    public Task<IReadOnlyList<float[]>> EmbedAsync(IReadOnlyList<string> texts, CancellationToken ct) =>
        throw new LlmException(LlmFailureKind.Unavailable, "Embedding không dùng trong test Api.");

    public Task<LlmAnswer> AnswerAsync(string question, IReadOnlyList<ContextPassage> passages, CancellationToken ct) =>
        throw new LlmException(LlmFailureKind.Unavailable, "Hỏi đáp không dùng trong test Api.");
}

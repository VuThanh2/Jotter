using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Jotter.Application;
using Microsoft.Extensions.Options;

namespace Jotter.Infrastructure;

// Anthropic không có API embedding nên phần này đi qua Voyage AI (đối tác embedding được Anthropic khuyến nghị).
public sealed class VoyageEmbeddingClient(IHttpClientFactory httpClientFactory, IOptions<LlmOptions> options)
{
    public const string HttpClientName = "voyage";

    private const int MaxInputsPerRequest = 1_000;

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
    };

    private readonly LlmOptions _options = options.Value;

    public async Task<IReadOnlyList<float[]>> EmbedAsync(IReadOnlyList<string> texts, CancellationToken ct)
    {
        if (!_options.IsEmbeddingConfigured)
        {
            throw new LlmException(LlmFailureKind.Unavailable, "Chưa cấu hình khoá API cho dịch vụ embedding.");
        }

        var vectors = new List<float[]>(texts.Count);
        foreach (var batch in texts.Chunk(MaxInputsPerRequest))
        {
            vectors.AddRange(await EmbedBatchAsync(batch, ct));
        }

        return vectors;
    }

    private async Task<IEnumerable<float[]>> EmbedBatchAsync(string[] texts, CancellationToken ct)
    {
        var client = httpClientFactory.CreateClient(HttpClientName);
        var request = new EmbeddingRequest(texts, _options.EmbeddingModel);

        HttpResponseMessage response;
        try
        {
            response = await client.PostAsJsonAsync("embeddings", request, JsonOptions, ct);
        }
        catch (Exception ex) when (ex is HttpRequestException
            || (ex is TaskCanceledException && !ct.IsCancellationRequested))
        {
            throw new LlmException(LlmFailureKind.Unavailable, "Không kết nối được dịch vụ embedding.", ex);
        }

        using (response)
        {
            if (!response.IsSuccessStatusCode)
            {
                throw new LlmException(
                    response.StatusCode == HttpStatusCode.TooManyRequests
                        ? LlmFailureKind.QuotaExceeded
                        : LlmFailureKind.Unavailable,
                    $"Dịch vụ embedding trả về {(int)response.StatusCode}.");
            }

            var body = await response.Content.ReadFromJsonAsync<EmbeddingResponse>(JsonOptions, ct);
            if (body?.Data is not { Count: > 0 } data || data.Count != texts.Length)
            {
                throw new LlmException(LlmFailureKind.Unavailable, "Dịch vụ embedding trả về dữ liệu không hợp lệ.");
            }

            // Sắp theo index để giữ đúng thứ tự đầu vào, như ILlmService.EmbedAsync cam kết.
            return data.OrderBy(item => item.Index).Select(item => item.Embedding);
        }
    }

    private sealed record EmbeddingRequest(IReadOnlyList<string> Input, string Model);

    private sealed record EmbeddingResponse(IReadOnlyList<EmbeddingItem>? Data);

    private sealed record EmbeddingItem(int Index, float[] Embedding);
}

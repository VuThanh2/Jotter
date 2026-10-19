using System.Net;
using System.Text.Json;
using Jotter.Application;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Ranh giới với Gemini: request gửi đúng model, khoá và cấu hình; response được đọc đúng, kể cả khi
// bị chặn, bị cắt ngang hay hết hạn mức — những ca Application dựa vào để trả 503/429 thay vì 500.
public sealed class GeminiLlmServiceTests
{
    private const string ApiKey = "test-gemini-key";

    [Fact]
    public async Task Summarize_StreamsOnlyAnswerText_AndSendsTheConfiguredModelAndThinkingLevel()
    {
        var server = new StubGeminiServer(_ => StubGeminiServer.ServerSentEvents(
            """{"candidates":[{"content":{"role":"model","parts":[{"text":"đang nghĩ","thought":true}]}}]}""",
            """{"candidates":[{"content":{"role":"model","parts":[{"text":"Tuần 1 "}]}}]}""",
            """{"candidates":[{"content":{"role":"model","parts":[{"text":"chốt kiến trúc."}]},"finishReason":"STOP"}]}"""));
        using var service = CreateService(server);

        var chunks = await service.SummarizeAsync("Kế hoạch", "Tuần 1 chốt kiến trúc.", Ct).ToListAsync(Ct);

        Assert.Equal(["Tuần 1 ", "chốt kiến trúc."], chunks);

        var request = Assert.Single(server.Requests);
        Assert.Contains("models/gemini-3.5-flash-lite:streamGenerateContent", request.Uri.AbsolutePath);
        Assert.Equal(ApiKey, request.ApiKey);
        Assert.Contains("Tuần 1 chốt kiến trúc.", request.Text);
        Assert.Contains("You summarize a user's personal note.", request.Text);
        Assert.Contains("\"LOW\"", request.Text);
    }

    [Theory]
    [InlineData("MAX_TOKENS")]
    [InlineData("SAFETY")]
    public async Task Summarize_ThatStopsAbnormally_FailsInsteadOfLookingComplete(string finishReason)
    {
        var server = new StubGeminiServer(_ => StubGeminiServer.ServerSentEvents(
            """{"candidates":[{"content":{"role":"model","parts":[{"text":"Dở dang"}]}}]}""",
            $$"""{"candidates":[{"content":{"role":"model","parts":[{"text":"..."}]},"finishReason":"{{finishReason}}"}]}"""));
        using var service = CreateService(server);

        var ex = await Assert.ThrowsAsync<LlmException>(() => service.SummarizeAsync("Tiêu đề", "Nội dung", Ct).ToListAsync(Ct).AsTask());

        Assert.Equal(LlmFailureKind.Unavailable, ex.Kind);
    }

    [Fact]
    public async Task Answer_RequestsJsonMatchingTheSchema_AndParsesIt()
    {
        var answer = JsonSerializer.Serialize(new { answer = "Tuần 3 làm AI.", hasEnoughContext = true });
        var server = new StubGeminiServer(_ => StubGeminiServer.Json(JsonSerializer.Serialize(new
        {
            candidates = new[]
            {
                new { content = new { role = "model", parts = new[] { new { text = answer } } }, finishReason = "STOP" }
            }
        })));
        using var service = CreateService(server);

        var result = await service.AnswerAsync(
            "Tuần 3 làm gì?",
            [new ContextPassage("Kế hoạch", "Tuần 3 AI.")],
            Ct);

        Assert.Equal(new LlmAnswer("Tuần 3 làm AI.", HasEnoughContext: true), result);

        var request = Assert.Single(server.Requests);
        Assert.Contains("models/gemini-3.5-flash-lite:generateContent", request.Uri.AbsolutePath);
        Assert.Contains("application/json", request.Text);
        Assert.Contains("hasEnoughContext", request.Text);
        Assert.Contains("<passage note_title=\"Kế hoạch\">", request.Text);
    }

    [Fact]
    public async Task Answer_WhenThePromptIsBlocked_FailsAsUnavailable()
    {
        var server = new StubGeminiServer(_ => StubGeminiServer.Json("""{"promptFeedback":{"blockReason":"SAFETY"}}"""));
        using var service = CreateService(server);

        var ex = await Assert.ThrowsAsync<LlmException>(() =>
            service.AnswerAsync("Câu hỏi", [new ContextPassage("Note", "Nội dung")], Ct));

        Assert.Equal(LlmFailureKind.Unavailable, ex.Kind);
    }

    [Fact]
    public async Task Embed_ReturnsOneVectorPerText_InInputOrder_WithTheConfiguredDimensions()
    {
        var server = new StubGeminiServer(_ => StubGeminiServer.Json(
            """{"embeddings":[{"values":[0.1,0.2,0.3]},{"values":[0.4,0.5,0.6]}]}"""));
        using var service = CreateService(server);

        var vectors = await service.EmbedAsync(["một", "hai"], Ct);

        Assert.Equal(2, vectors.Count);
        Assert.Equal([0.1f, 0.2f, 0.3f], vectors[0]);
        Assert.Equal([0.4f, 0.5f, 0.6f], vectors[1]);

        var request = Assert.Single(server.Requests);
        Assert.Contains("models/gemini-embedding-2:batchEmbedContents", request.Uri.AbsolutePath);
        Assert.Contains("768", request.Text);
    }

    [Fact]
    public async Task Embed_WithAMissingVector_FailsInsteadOfMisaligningChunks()
    {
        var server = new StubGeminiServer(_ => StubGeminiServer.Json("""{"embeddings":[{"values":[0.1,0.2]}]}"""));
        using var service = CreateService(server);

        var ex = await Assert.ThrowsAsync<LlmException>(() => service.EmbedAsync(["một", "hai"], Ct));

        Assert.Equal(LlmFailureKind.Unavailable, ex.Kind);
    }

    // 429 của free tier phải thành QuotaExceeded để client nhận 429 và biết thử lại sau, không phải lỗi máy chủ.
    [Fact]
    public async Task RateLimitedRequests_MapToQuotaExceeded()
    {
        var server = new StubGeminiServer(_ => StubGeminiServer.Json(
            """{"error":{"code":429,"message":"Resource has been exhausted","status":"RESOURCE_EXHAUSTED"}}""",
            HttpStatusCode.TooManyRequests));
        using var service = CreateService(server);

        var ex = await Assert.ThrowsAsync<LlmException>(() => service.EmbedAsync(["một"], Ct));

        Assert.Equal(LlmFailureKind.QuotaExceeded, ex.Kind);
    }

    [Fact]
    public async Task WithoutAnApiKey_FailsAsUnavailable_WithoutCallingTheProvider()
    {
        var server = new StubGeminiServer(_ => throw new InvalidOperationException("Không được gọi ra mạng."));
        using var service = CreateService(server, apiKey: null);

        var ex = await Assert.ThrowsAsync<LlmException>(() => service.EmbedAsync(["một"], Ct));

        Assert.Equal(LlmFailureKind.Unavailable, ex.Kind);
        Assert.Empty(server.Requests);
    }

    private static GeminiLlmService CreateService(StubGeminiServer server, string? apiKey = ApiKey) =>
        new(
            Options.Create(new LlmOptions { ApiKey = apiKey }),
            server,
            NullLogger<GeminiLlmService>.Instance);
}

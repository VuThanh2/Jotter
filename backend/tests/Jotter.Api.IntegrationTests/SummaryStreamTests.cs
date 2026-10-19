using System.Net;
using System.Text.Json;
using Xunit;
using static Jotter.Api.IntegrationTests.ApiClientExtensions;

namespace Jotter.Api.IntegrationTests;

// Provider giả thay cho Gemini để kiểm đúng phần của Api: text/event-stream, tên sự kiện, JSON của từng sự kiện theo
// kiểu thực tế của nó (không phải kiểu cơ sở rỗng), và bản tóm tắt được lưu khi luồng kết thúc.
public sealed class SummaryStreamTests(ApiFixture api)
{
    [Fact]
    public async Task GeneratingASummary_StreamsDeltasThenCompleted_AndPersistsTheResult()
    {
        using var client = await api.CreateUserClientAsync();
        var noteId = await client.CreateNoteAsync("Tuần 1 chốt kiến trúc, tuần 2 đồng bộ, tuần 3 AI, tuần 4 kiểm thử.");
        var expectedSummary = string.Concat(FakeLlmService.SummaryChunks);

        using var response = await client.PostAsync($"/api/notes/{noteId}/summary", content: null, Ct);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("text/event-stream", response.Content.Headers.ContentType?.MediaType);

        var events = ParseEvents(await response.Content.ReadAsStringAsync(Ct));
        Assert.Equal(["delta", "delta", "completed"], events.Select(e => e.Type));
        Assert.Equal(FakeLlmService.SummaryChunks, events.Take(2).Select(e => e.Data.GetProperty("delta").GetString()));
        Assert.Equal(expectedSummary, events[^1].Data.GetProperty("summaryText").GetString());

        using var saved = await client.GetAsync($"/api/notes/{noteId}/summary", Ct);
        Assert.Equal(HttpStatusCode.OK, saved.StatusCode);
        Assert.Equal(expectedSummary, (await saved.ReadJsonAsync()).GetProperty("summaryText").GetString());
    }

    private static List<(string Type, JsonElement Data)> ParseEvents(string stream) =>
        stream
            .Split("\n\n", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(block => block.Split('\n'))
            .Select(lines => (
                Type: lines.Single(line => line.StartsWith("event: ", StringComparison.Ordinal))["event: ".Length..],
                Data: JsonSerializer.Deserialize<JsonElement>(
                    lines.Single(line => line.StartsWith("data: ", StringComparison.Ordinal))["data: ".Length..])))
            .ToList();
}

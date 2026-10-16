using Jotter.Application;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Jotter.Api;

[ApiController]
[Route("api")]
[EnableRateLimiting(RateLimitPolicies.Llm)]
public sealed class AiController : ControllerBase
{
    // text/event-stream: các sự kiện "delta" rồi "completed" (hoặc "failed" nếu provider lỗi giữa chừng).
    // Client ngắt kết nối là huỷ việc sinh tóm tắt — CancellationToken gắn với request abort.
    [HttpPost("notes/{noteId:guid}/summary")]
    [Produces("text/event-stream")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> GenerateSummary(
        Guid noteId,
        [FromServices] GenerateSummaryCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, ct);
        return result.ToServerSentEventsResult(EventTypeOf);
    }

    // Đọc bản đã lưu không tốn hạn mức LLM.
    [HttpGet("notes/{noteId:guid}/summary")]
    [DisableRateLimiting]
    [ProducesResponseType<GetSummaryOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetSummary(Guid noteId, [FromServices] GetSummaryQuery query, CancellationToken ct)
    {
        var result = await query.ExecuteAsync(noteId, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpPost("ai/ask")]
    [ProducesResponseType<AskNotesOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Ask(
        [FromBody] AskNotesInputDto input,
        [FromServices] AskNotesQuery query,
        CancellationToken ct)
    {
        var result = await query.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    private static string EventTypeOf(GenerateSummaryEventDto summaryEvent) => summaryEvent switch
    {
        GenerateSummaryDeltaDto => "delta",
        GenerateSummaryCompletedDto => "completed",
        GenerateSummaryFailedDto => "failed",
        _ => throw new ArgumentOutOfRangeException(nameof(summaryEvent), summaryEvent.GetType().Name, null)
    };
}

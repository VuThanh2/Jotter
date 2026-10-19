using Jotter.Application;
using Microsoft.AspNetCore.Mvc;

namespace Jotter.Api;

[ApiController]
[Route("api/realtime")]
public sealed class RealtimeController : ControllerBase
{
    // Token TTL ngắn, scope "ws", chỉ dùng để mở kết nối /ws?token=... — REST từ chối loại token này.
    [HttpPost("token")]
    [ProducesResponseType<IssueRealtimeTokenOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> IssueToken([FromServices] IssueRealtimeTokenCommand command, CancellationToken ct)
    {
        var result = await command.ExecuteAsync(ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }
}

using Jotter.Application;
using Microsoft.AspNetCore.Mvc;

namespace Jotter.Api;

// Chỉ có chiều đọc: outbox đẩy thay đổi qua đúng các endpoint ghi thông thường, không có đường ghi thứ hai.
[ApiController]
[Route("api/sync")]
public sealed class SyncController : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<PullChangesOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Pull(
        [FromQuery] PullChangesInputDto input,
        [FromServices] PullChangesQuery query,
        CancellationToken ct)
    {
        var result = await query.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }
}

using Jotter.Application;
using Microsoft.AspNetCore.Mvc;

namespace Jotter.Api;

[ApiController]
[Route("api/labels")]
public sealed class LabelsController : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<ListLabelsOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> List([FromServices] ListLabelsQuery query, CancellationToken ct)
    {
        var result = await query.ExecuteAsync(ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpPost]
    [Idempotent]
    [ProducesResponseType<CreateLabelOutputDto>(StatusCodes.Status201Created)]
    public async Task<IActionResult> Create(
        [FromBody] CreateLabelInputDto input,
        [FromServices] CreateLabelCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status201Created);
    }

    [HttpPut("{labelId:guid}")]
    [Idempotent]
    [ProducesResponseType<RenameLabelOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Rename(
        Guid labelId,
        [FromBody] RenameLabelInputDto input,
        [FromServices] RenameLabelCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(labelId, input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    // Chỉ gỡ liên kết khỏi các note, không chạm nội dung note.
    [HttpDelete("{labelId:guid}")]
    [Idempotent]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(Guid labelId, [FromServices] DeleteLabelCommand command, CancellationToken ct)
    {
        var result = await command.ExecuteAsync(labelId, ct);
        return result.ToActionResult(StatusCodes.Status204NoContent);
    }
}

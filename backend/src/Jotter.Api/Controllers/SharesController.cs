using Jotter.Application;
using Microsoft.AspNetCore.Mvc;

namespace Jotter.Api;

[ApiController]
[Route("api")]
public sealed class SharesController : ControllerBase
{
    [HttpGet("notes/{noteId:guid}/shares")]
    [ProducesResponseType<ListSharesOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> List(Guid noteId, [FromServices] ListSharesQuery query, CancellationToken ct)
    {
        var result = await query.ExecuteAsync(noteId, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    // Xử lý theo từng người nhận: 201 kể cả khi một phần bị từ chối (xem "rejected").
    [HttpPost("notes/{noteId:guid}/shares")]
    [Idempotent]
    [ProducesResponseType<ShareNoteOutputDto>(StatusCodes.Status201Created)]
    public async Task<IActionResult> Share(
        Guid noteId,
        [FromBody] ShareNoteInputDto input,
        [FromServices] ShareNoteCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, input, ct);
        return result.ToActionResult(StatusCodes.Status201Created);
    }

    [HttpPut("notes/{noteId:guid}/shares/{shareId:guid}")]
    [Idempotent]
    [ProducesResponseType<ChangeSharePermissionOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> ChangePermission(
        Guid noteId,
        Guid shareId,
        [FromBody] ChangeSharePermissionInputDto input,
        [FromServices] ChangeSharePermissionCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, shareId, input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpDelete("notes/{noteId:guid}/shares/{shareId:guid}")]
    [Idempotent]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Revoke(
        Guid noteId,
        Guid shareId,
        [FromServices] RevokeShareCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, shareId, ct);
        return result.ToActionResult(StatusCodes.Status204NoContent);
    }

    [HttpGet("shared-with-me")]
    [ProducesResponseType<CursorPage<ListSharedWithMeItemDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> ListSharedWithMe(
        [FromQuery] ListSharedWithMeInputDto input,
        [FromServices] ListSharedWithMeQuery query,
        CancellationToken ct)
    {
        var result = await query.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }
}

using Jotter.Application;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Jotter.Api;

[ApiController]
[Route("api/notes/{noteId:guid}")]
public sealed class NoteProtectionController : ControllerBase
{
    [HttpPost("protection")]
    [Idempotent]
    [ProducesResponseType<EnableProtectionOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Enable(
        Guid noteId,
        [FromBody] EnableProtectionInputDto input,
        [FromServices] EnableProtectionCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    // Không [Idempotent]: phát lại response cũ có thể trả về một phiên mở khoá đã hết hạn.
    [HttpPost("unlock")]
    [EnableRateLimiting(RateLimitPolicies.NoteUnlock)]
    [ProducesResponseType<UnlockNoteOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Unlock(
        Guid noteId,
        [FromBody] UnlockNoteInputDto input,
        [FromServices] UnlockNoteCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpDelete("unlock")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> EndUnlock(Guid noteId, [FromServices] EndUnlockCommand command, CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, ct);
        return result.ToActionResult(StatusCodes.Status204NoContent);
    }

    [HttpPut("protection/password")]
    [Idempotent]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ChangePassword(
        Guid noteId,
        [FromBody] ChangeNotePasswordInputDto input,
        [FromServices] ChangeNotePasswordCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, input, ct);
        return result.ToActionResult(StatusCodes.Status204NoContent);
    }

    // POST thay vì DELETE vì cần thân yêu cầu chứa mật khẩu — không đặt mật khẩu lên query string.
    [HttpPost("protection/disable")]
    [Idempotent]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Disable(
        Guid noteId,
        [FromBody] DisableProtectionInputDto input,
        [FromServices] DisableProtectionCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, input, ct);
        return result.ToActionResult(StatusCodes.Status204NoContent);
    }
}

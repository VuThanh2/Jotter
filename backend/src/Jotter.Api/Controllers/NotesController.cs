using Jotter.Application;
using Microsoft.AspNetCore.Mvc;

namespace Jotter.Api;

[ApiController]
[Route("api/notes")]
public sealed class NotesController : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<CursorPage<ListNotesItemDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> List(
        [FromQuery] ListNotesInputDto input,
        [FromServices] ListNotesQuery query,
        CancellationToken ct)
    {
        var result = await query.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    // Note đang khoá trả 423 kèm metadata (không có content) trong trường "note" của ProblemDetails.
    [HttpGet("{noteId:guid}")]
    [ProducesResponseType<GetNoteOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Get(Guid noteId, [FromServices] GetNoteQuery query, CancellationToken ct)
    {
        var result = await query.ExecuteAsync(noteId, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpGet("{noteId:guid}/version")]
    [ProducesResponseType<GetNoteVersionOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetVersion(
        Guid noteId,
        [FromServices] GetNoteVersionQuery query,
        CancellationToken ct)
    {
        var result = await query.ExecuteAsync(noteId, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpPost]
    [Idempotent]
    [ProducesResponseType<CreateNoteOutputDto>(StatusCodes.Status201Created)]
    public async Task<IActionResult> Create(
        [FromBody] CreateNoteInputDto input,
        [FromServices] CreateNoteCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status201Created);
    }

    // Lệch baseVersion trả 409 VersionConflict kèm "serverNote" để client tạo Conflict Copy.
    [HttpPut("{noteId:guid}")]
    [Idempotent]
    [ProducesResponseType<UpdateNoteContentOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateContent(
        Guid noteId,
        [FromBody] UpdateNoteContentInputDto input,
        [FromServices] UpdateNoteContentCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpDelete("{noteId:guid}")]
    [Idempotent]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(Guid noteId, [FromServices] DeleteNoteCommand command, CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, ct);
        return result.ToActionResult(StatusCodes.Status204NoContent);
    }

    [HttpPut("{noteId:guid}/pin")]
    [Idempotent]
    [ProducesResponseType<PinNoteOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Pin(
        Guid noteId,
        [FromBody] PinNoteInputDto input,
        [FromServices] PinNoteCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpPut("{noteId:guid}/labels")]
    [Idempotent]
    [ProducesResponseType<SetNoteLabelsOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> SetLabels(
        Guid noteId,
        [FromBody] SetNoteLabelsInputDto input,
        [FromServices] SetNoteLabelsCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(noteId, input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }
}

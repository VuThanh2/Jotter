using Jotter.Application;
using Microsoft.AspNetCore.Mvc;

namespace Jotter.Api;

[ApiController]
[Route("api/me")]
public sealed class MeController : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<GetMeOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetMe([FromServices] GetMeQuery query, CancellationToken ct)
    {
        var result = await query.ExecuteAsync(ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpPut]
    [ProducesResponseType<UpdateProfileOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateProfile(
        [FromBody] UpdateProfileInputDto input,
        [FromServices] UpdateProfileCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpPost("avatar")]
    [ProducesResponseType<UploadAvatarOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> UploadAvatar(
        [FromForm] IFormFile file,
        [FromServices] UploadAvatarCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(file.ToFileUploadDto(Response), ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpDelete("avatar")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> RemoveAvatar([FromServices] RemoveAvatarCommand command, CancellationToken ct)
    {
        var result = await command.ExecuteAsync(ct);
        return result.ToActionResult(StatusCodes.Status204NoContent);
    }

    [HttpGet("preferences")]
    [ProducesResponseType<GetPreferencesOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPreferences([FromServices] GetPreferencesQuery query, CancellationToken ct)
    {
        var result = await query.ExecuteAsync(ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpPut("preferences")]
    [ProducesResponseType<UpdatePreferencesOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdatePreferences(
        [FromBody] UpdatePreferencesInputDto input,
        [FromServices] UpdatePreferencesCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }
}

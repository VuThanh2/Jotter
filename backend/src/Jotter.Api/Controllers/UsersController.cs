using Jotter.Application;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Jotter.Api;

[ApiController]
[Route("api/users")]
public sealed class UsersController : ControllerBase
{
    private const int AvatarCacheSeconds = 24 * 60 * 60;

    // Đích của avatarUrl. Công khai vì thẻ <img> trên web không gắn được header Authorization.
    // Cache được vì URL mang tham số v đổi theo mỗi lần tải ảnh mới.
    [HttpGet("{userId:guid}/avatar")]
    [AllowAnonymous]
    [ResponseCache(Duration = AvatarCacheSeconds, Location = ResponseCacheLocation.Any)]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAvatar(Guid userId, [FromServices] GetAvatarQuery query, CancellationToken ct)
    {
        var result = await query.ExecuteAsync(userId, ct);
        return result.ToActionResult(avatar => File(avatar.Content, avatar.MimeType));
    }
}

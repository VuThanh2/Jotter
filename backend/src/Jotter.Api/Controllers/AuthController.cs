using Jotter.Application;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Jotter.Api;

[ApiController]
[Route("api/auth")]
public sealed class AuthController : ControllerBase
{
    [HttpPost("register")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.Auth)]
    [ProducesResponseType<RegisterOutputDto>(StatusCodes.Status201Created)]
    public async Task<IActionResult> Register(
        [FromBody] RegisterInputDto input,
        [FromServices] RegisterCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status201Created);
    }

    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.Auth)]
    [ProducesResponseType<LoginOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Login(
        [FromBody] LoginInputDto input,
        [FromServices] LoginCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    // sessionId lấy từ token, không bao giờ từ body: chỉ đúng thiết bị đang gọi bị đăng xuất.
    [HttpPost("logout")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Logout([FromServices] LogoutCommand command, CancellationToken ct)
    {
        var result = await command.ExecuteAsync(ct);
        return result.ToActionResult(StatusCodes.Status204NoContent);
    }

    [HttpPost("activation/resend")]
    [EnableRateLimiting(RateLimitPolicies.OtpSend)]
    [ProducesResponseType<ResendActivationOutputDto>(StatusCodes.Status202Accepted)]
    public async Task<IActionResult> ResendActivation(
        [FromServices] ResendActivationCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(ct);
        return result.ToActionResult(StatusCodes.Status202Accepted);
    }

    [HttpPost("activation/confirm")]
    [EnableRateLimiting(RateLimitPolicies.OtpVerify)]
    [ProducesResponseType<ConfirmActivationOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> ConfirmActivation(
        [FromBody] ConfirmActivationInputDto input,
        [FromServices] ConfirmActivationCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    // Luôn 202 dù email có tồn tại hay không — gọi lại chính endpoint này là "gửi lại mã".
    [HttpPost("password/forgot")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.OtpSend)]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    public async Task<IActionResult> ForgotPassword(
        [FromBody] ForgotPasswordInputDto input,
        [FromServices] ForgotPasswordCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status202Accepted);
    }

    [HttpPost("password/verify-code")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.OtpVerify)]
    [ProducesResponseType<VerifyResetCodeOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> VerifyResetCode(
        [FromBody] VerifyResetCodeInputDto input,
        [FromServices] VerifyResetCodeCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }

    [HttpPost("password/reset")]
    [AllowAnonymous]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ResetPassword(
        [FromBody] ResetPasswordInputDto input,
        [FromServices] ResetPasswordCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status204NoContent);
    }

    // Token mới trả ngay trong response: stamp vừa xoay nên thiết bị hiện tại không tự đá chính mình.
    [HttpPost("password/change")]
    [EnableRateLimiting(RateLimitPolicies.Auth)]
    [ProducesResponseType<ChangePasswordOutputDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> ChangePassword(
        [FromBody] ChangePasswordInputDto input,
        [FromServices] ChangePasswordCommand command,
        CancellationToken ct)
    {
        var result = await command.ExecuteAsync(input, ct);
        return result.ToActionResult(StatusCodes.Status200OK);
    }
}

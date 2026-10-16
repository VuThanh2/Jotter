using System.Net;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
using static Jotter.Api.IntegrationTests.ApiClientExtensions;

namespace Jotter.Api.IntegrationTests;

public sealed class SecurityTests(ApiFixture api)
{
    // Toàn bộ ngoại lệ có chủ đích của fallback policy "mọi endpoint đều cần đăng nhập".
    private static readonly string[] IntendedAnonymousRoutes =
    [
        "api/auth/login",
        "api/auth/password/forgot",
        "api/auth/password/reset",
        "api/auth/password/verify-code",
        "api/auth/register",
        "api/users/{userId:guid}/avatar",
        "health",
        "health/ready",
        "openapi/{documentName}.json"
    ];

    // Lỡ tay gắn [AllowAnonymous] hay map một endpoint mới thiếu bảo vệ là dữ liệu bị lộ mà không test nghiệp vụ nào
    // phát hiện được; test này so toàn bộ bảng định tuyến với danh sách được phép.
    [Fact]
    public void OnlyTheIntendedEndpoints_AreReachableWithoutLogin()
    {
        var anonymousRoutes = api.Services.GetRequiredService<EndpointDataSource>().Endpoints
            .OfType<RouteEndpoint>()
            .Where(endpoint => endpoint.Metadata.GetMetadata<IAllowAnonymous>() is not null)
            .Select(endpoint => endpoint.RoutePattern.RawText!.TrimStart('/'))
            .Distinct()
            .Order(StringComparer.Ordinal);

        Assert.Equal(IntendedAnonymousRoutes.Order(StringComparer.Ordinal), anonymousRoutes);
    }

    // Use case không tự đếm lần nhập sai mật khẩu note mà giao hẳn cho rate limiter, nên đây là lớp chặn đoán mật khẩu
    // duy nhất. Hạn mức tính riêng từng note: đoán sai note này không được khoá việc mở note khác.
    [Fact]
    public async Task GuessingANotePassword_IsThrottledPerNote()
    {
        using var client = await api.CreateUserClientAsync();
        var target = await client.CreateProtectedNoteAsync();
        var otherNote = await client.CreateProtectedNoteAsync();
        var permitLimit = new RateLimitOptions().NoteUnlock.PermitLimit;

        for (var attempt = 0; attempt < permitLimit; attempt++)
        {
            using var wrongGuess = await client.SendJsonAsync(
                HttpMethod.Post,
                $"/api/notes/{target}/unlock",
                new { password = "sai-mat-khau" });
            await wrongGuess.ReadProblemAsync(HttpStatusCode.BadRequest, "InvalidNotePassword");
        }

        using var throttled = await client.SendJsonAsync(
            HttpMethod.Post,
            $"/api/notes/{target}/unlock",
            new { password = NotePassword });
        await throttled.ReadProblemAsync(HttpStatusCode.TooManyRequests, "TooManyAttempts");
        Assert.NotNull(throttled.Headers.RetryAfter);

        using var unaffected = await client.SendJsonAsync(
            HttpMethod.Post,
            $"/api/notes/{otherNote}/unlock",
            new { password = NotePassword });
        Assert.Equal(HttpStatusCode.OK, unaffected.StatusCode);
    }
}

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Net.WebSockets;
using System.Text;
using Jotter.Application;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Đi qua pipeline HTTP thật (JwtBearer, SessionValidator, policy) bằng TestServer: các luật về loại token và
// thu hồi phiên nằm ở cấu hình xác thực, nên chỉ kiểm được khi request thật sự đi qua middleware.
public sealed class AuthPipelineTests(PostgresFixture postgres) : IAsyncLifetime
{
    // Thư mục riêng: app chạy đủ tác vụ nền, kể cả tác vụ xoá tệp không được tham chiếu trong thư mục lưu trữ.
    private readonly string _storageRoot = Path.Combine(Path.GetTempPath(), "jotter-tests", Guid.NewGuid().ToString("N"));

    private WebApplication _app = null!;
    private HttpClient _client = null!;

    public async ValueTask InitializeAsync()
    {
        var connectionString = await postgres.CreateDatabaseAsync();
        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseTestServer();
        builder.Logging.ClearProviders();
        builder.Configuration.AddConfiguration(TestServices.Configuration(connectionString, _storageRoot));
        builder.Services.AddInfrastructure(builder.Configuration);
        builder.Services.AddApplicationUseCases();

        _app = builder.Build();
        _app.UseWebSockets();
        _app.UseAuthentication();
        _app.UseAuthorization();
        MapProbeEndpoints(_app);

        await _app.StartAsync();
        _client = _app.GetTestClient();
    }

    [Fact]
    public async Task RestEndpoints_AcceptOnlyAccessTokensInTheAuthorizationHeader()
    {
        var account = await RegisterAsync();
        var realtimeToken = await IssueRealtimeTokenAsync(account.AccessToken);

        Assert.Equal(HttpStatusCode.OK, await GetStatusAsync("/probe", account.AccessToken));
        Assert.Equal(HttpStatusCode.Unauthorized, await GetStatusAsync("/probe", token: null));
        Assert.Equal(HttpStatusCode.Forbidden, await GetStatusAsync("/probe", realtimeToken));
        Assert.Equal(HttpStatusCode.Unauthorized, await GetStatusAsync($"/probe?token={account.AccessToken}", token: null));
    }

    [Fact]
    public async Task RealtimeEndpoint_AcceptsOnlyTheShortLivedRealtimeToken()
    {
        var account = await RegisterAsync();
        var realtimeToken = await IssueRealtimeTokenAsync(account.AccessToken);

        await Assert.ThrowsAnyAsync<Exception>(() => ConnectAsync(account.AccessToken));
        using var socket = await ConnectAsync(realtimeToken);

        Assert.Equal(WebSocketState.Open, socket.State);
    }

    // Không cache kết quả kiểm phiên: đăng xuất ở thiết bị này thì token của nó bị từ chối ngay request kế tiếp.
    [Fact]
    public async Task LoggingOut_RejectsThatTokenOnTheVeryNextRequest()
    {
        var account = await RegisterAsync();

        using var logout = new HttpRequestMessage(HttpMethod.Post, "/logout");
        logout.Headers.Authorization = new AuthenticationHeaderValue("Bearer", account.AccessToken);
        (await _client.SendAsync(logout, Ct)).EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.Unauthorized, await GetStatusAsync("/probe", account.AccessToken));
    }

    // Không tin noteId client gửi: join đi qua cùng INoteAccessPolicy với REST.
    [Fact]
    public async Task JoiningANoteChannel_IsAuthorizedPerNote()
    {
        var account = await RegisterAsync();
        var ownNoteId = await CreateNoteAsync(account.AccessToken);
        using var socket = await ConnectAsync(await IssueRealtimeTokenAsync(account.AccessToken));

        var foreignReply = await SendAsync(socket, $$"""{"type":"join","noteId":"{{Guid.NewGuid()}}"}""");
        var ownReply = await SendAsync(socket, $$"""{"type":"join","noteId":"{{ownNoteId}}"}""");

        Assert.Contains("\"forbidden\"", foreignReply);
        Assert.Contains("\"presence\"", ownReply);
    }

    public async ValueTask DisposeAsync()
    {
        _client.Dispose();
        await _app.DisposeAsync();

        if (Directory.Exists(_storageRoot))
        {
            Directory.Delete(_storageRoot, recursive: true);
        }
    }

    private static void MapProbeEndpoints(WebApplication app)
    {
        app.MapGet("/probe", (ICurrentUser user) => user.UserId);
        app.MapPost("/register", [AllowAnonymous] async (RegisterInputDto input, RegisterCommand command, CancellationToken ct) =>
            (await command.ExecuteAsync(input, ct)).Value);
        app.MapPost("/logout", async (LogoutCommand command, CancellationToken ct) =>
        {
            await command.ExecuteAsync(ct);
            return Results.NoContent();
        });
        app.MapPost("/realtime-token", async (IssueRealtimeTokenCommand command, CancellationToken ct) =>
            (await command.ExecuteAsync(ct)).Value);
        app.MapPost("/notes", async (CreateNoteCommand command, CancellationToken ct) =>
            (await command.ExecuteAsync(new CreateNoteInputDto(Guid.CreateVersion7(), "Tiêu đề", "Nội dung", null), ct)).Value);
        app.Map(WebSocketHandler.Path, (HttpContext context, WebSocketHandler handler) => handler.HandleAsync(context))
            .RequireAuthorization(WebSocketHandler.AuthorizationPolicy);
    }

    private async Task<RegisterOutputDto> RegisterAsync()
    {
        var input = new RegisterInputDto($"{Guid.NewGuid():N}@jotter.test", "Người dùng", Password, Password);
        var response = await _client.PostAsJsonAsync("/register", input, Ct);
        return (await response.Content.ReadFromJsonAsync<RegisterOutputDto>(Ct))!;
    }

    private async Task<string> IssueRealtimeTokenAsync(string accessToken) =>
        (await PostAsync<IssueRealtimeTokenOutputDto>("/realtime-token", accessToken)).Token;

    private async Task<Guid> CreateNoteAsync(string accessToken) =>
        (await PostAsync<CreateNoteOutputDto>("/notes", accessToken)).NoteId;

    private async Task<T> PostAsync<T>(string path, string accessToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, path);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        var response = await _client.SendAsync(request, Ct);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<T>(Ct))!;
    }

    private async Task<HttpStatusCode> GetStatusAsync(string path, string? token)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, path);
        if (token is not null)
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        }

        return (await _client.SendAsync(request, Ct)).StatusCode;
    }

    private Task<WebSocket> ConnectAsync(string token) =>
        _app.GetTestServer().CreateWebSocketClient()
            .ConnectAsync(new Uri($"ws://localhost{WebSocketHandler.Path}?token={token}"), Ct);

    private static async Task<string> SendAsync(WebSocket socket, string message)
    {
        await socket.SendAsync(Encoding.UTF8.GetBytes(message), WebSocketMessageType.Text, endOfMessage: true, Ct);

        var buffer = new byte[4096];
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(Ct);
        timeout.CancelAfter(TimeSpan.FromSeconds(10));
        var received = await socket.ReceiveAsync(buffer, timeout.Token);
        return Encoding.UTF8.GetString(buffer, 0, received.Count);
    }
}

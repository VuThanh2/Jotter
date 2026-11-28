using System.ComponentModel.DataAnnotations;
using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Xunit;
using static Jotter.Infrastructure.IntegrationTests.TestData;

namespace Jotter.Infrastructure.IntegrationTests;

// Kênh gửi được chọn theo cấu hình: local chỉ có SMTP thì vẫn đi MailKit, Railway có khoá Mailjet thì đi HTTPS.
public sealed class EmailTransportTests
{
    private const string ApiKey = "test-mailjet-key";
    private const string SecretKey = "test-mailjet-secret";

    private const string AcceptedResponse =
        """{"Messages":[{"Status":"success","To":[{"Email":"an@example.com","MessageID":1}]}]}""";

    [Theory]
    [InlineData(null, null, null, typeof(LoggingEmailTransport))]
    [InlineData(null, null, "smtp.gmail.com", typeof(MailKitEmailTransport))]
    [InlineData(ApiKey, SecretKey, null, typeof(MailjetEmailTransport))]
    [InlineData(ApiKey, SecretKey, "smtp.gmail.com", typeof(MailjetEmailTransport))]
    public void AddInfrastructure_PicksTheTransportFromConfiguration(
        string? apiKey,
        string? secretKey,
        string? smtpHost,
        Type expected)
    {
        var configuration = new ConfigurationBuilder()
            .AddConfiguration(TestServices.Configuration("Host=localhost;Database=unused", "unused-storage-root"))
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Email:MailjetApiKey"] = apiKey,
                ["Email:MailjetSecretKey"] = secretKey,
                ["Email:Host"] = smtpHost,
                ["Email:From"] = "jotter@example.com"
            })
            .Build();
        var services = new ServiceCollection();
        services.AddSingleton<IConfiguration>(configuration);
        services.AddLogging();
        services.AddInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();

        Assert.IsType(expected, provider.GetRequiredService<IEmailTransport>());
    }

    [Fact]
    public void EmailOptions_WithMailjetKeysButNoSender_FailsValidation()
    {
        var options = new EmailOptions { MailjetApiKey = ApiKey, MailjetSecretKey = SecretKey };

        Assert.Single(Validate(options));
    }

    [Theory]
    [InlineData(ApiKey, null)]
    [InlineData(null, SecretKey)]
    public void EmailOptions_WithOnlyOneMailjetKey_FailsValidation(string? apiKey, string? secretKey)
    {
        var options = new EmailOptions { MailjetApiKey = apiKey, MailjetSecretKey = secretKey, From = "jotter@example.com" };

        Assert.Single(Validate(options));
    }

    [Fact]
    public async Task Mailjet_PostsTheMessageWithBasicAuthAndSender()
    {
        var server = new StubMailjetServer(HttpStatusCode.OK, AcceptedResponse);
        var transport = CreateTransport(server);

        await transport.SendAsync(
            new EmailMessage("an@example.com", "An", "Mã kích hoạt", "<p>123456</p>", "123456"),
            Ct);

        var request = Assert.Single(server.Requests);
        Assert.Equal(HttpMethod.Post, request.Method);
        Assert.Equal("https://api.mailjet.com/v3.1/send", request.Uri.ToString());
        Assert.Equal("Basic", request.AuthScheme);
        Assert.Equal($"{ApiKey}:{SecretKey}", Encoding.UTF8.GetString(Convert.FromBase64String(request.AuthParameter!)));

        using var body = JsonDocument.Parse(request.Body);
        var message = Assert.Single(body.RootElement.GetProperty("Messages").EnumerateArray());
        Assert.Equal("jotter@example.com", message.GetProperty("From").GetProperty("Email").GetString());
        Assert.Equal("Jotter", message.GetProperty("From").GetProperty("Name").GetString());
        Assert.Equal("an@example.com", message.GetProperty("To")[0].GetProperty("Email").GetString());
        Assert.Equal("An", message.GetProperty("To")[0].GetProperty("Name").GetString());
        Assert.Equal("Mã kích hoạt", message.GetProperty("Subject").GetString());
        Assert.Equal("<p>123456</p>", message.GetProperty("HTMLPart").GetString());
        Assert.Equal("123456", message.GetProperty("TextPart").GetString());
    }

    // EmailDispatcherJobService chỉ thử lại khi transport ném lỗi, nên lỗi từ Mailjet không được nuốt im lặng.
    [Fact]
    public async Task Mailjet_ThatRejectsTheMessage_Throws()
    {
        var server = new StubMailjetServer(
            HttpStatusCode.BadRequest,
            """{"Messages":[{"Status":"error","Errors":[{"ErrorMessage":"sender not validated"}]}]}""");
        var transport = CreateTransport(server);

        var ex = await Assert.ThrowsAsync<HttpRequestException>(() => transport.SendAsync(
            new EmailMessage("an@example.com", "An", "Tiêu đề", "<p>x</p>", "x"),
            Ct));

        Assert.Equal(HttpStatusCode.BadRequest, ex.StatusCode);
        Assert.Contains("sender not validated", ex.Message);
    }

    [Fact]
    public async Task Mailjet_ThatAnswersOkButMarksTheMessageAsError_Throws()
    {
        var server = new StubMailjetServer(HttpStatusCode.OK, """{"Messages":[{"Status":"error"}]}""");
        var transport = CreateTransport(server);

        await Assert.ThrowsAsync<HttpRequestException>(() => transport.SendAsync(
            new EmailMessage("an@example.com", "An", "Tiêu đề", "<p>x</p>", "x"),
            Ct));
    }

    private static List<ValidationResult> Validate(EmailOptions options) =>
        options.Validate(new ValidationContext(options)).ToList();

    private static MailjetEmailTransport CreateTransport(StubMailjetServer server) =>
        new(server, Options.Create(new EmailOptions
        {
            MailjetApiKey = ApiKey,
            MailjetSecretKey = SecretKey,
            From = "jotter@example.com"
        }));

    private sealed class StubMailjetServer(HttpStatusCode status, string responseBody) : HttpMessageHandler, IHttpClientFactory
    {
        public List<RecordedRequest> Requests { get; } = [];

        public HttpClient CreateClient(string name) => new(this, disposeHandler: false);

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            var body = request.Content is null ? string.Empty : await request.Content.ReadAsStringAsync(ct);
            var auth = request.Headers.Authorization;
            Requests.Add(new RecordedRequest(request.Method, request.RequestUri!, auth?.Scheme, auth?.Parameter, body));

            return new HttpResponseMessage(status) { Content = new StringContent(responseBody) };
        }
    }

    private sealed record RecordedRequest(
        HttpMethod Method,
        Uri Uri,
        string? AuthScheme,
        string? AuthParameter,
        string Body);
}

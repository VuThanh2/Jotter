using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Jotter.Infrastructure;

// Gửi qua HTTPS Send API v3.1 của Mailjet vì Railway (gói Free/Hobby) chặn cổng SMTP ra ngoài, nên MailKit không gửi
// được từ đó. Chỉ được tạo khi EmailOptions.IsMailjetConfigured; máy local không đặt khoá Mailjet nên vẫn đi SMTP như cũ.
public sealed class MailjetEmailTransport : IEmailTransport
{
    public const string HttpClientName = "mailjet";

    private static readonly Uri SendEndpoint = new("https://api.mailjet.com/v3.1/send");

    // JsonContent mặc định đổi tên sang camelCase; Mailjet đòi đúng PascalCase (Messages, HTMLPart...) nên giữ nguyên tên.
    private static readonly JsonSerializerOptions PayloadJson = new();

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly EmailOptions _options;
    private readonly AuthenticationHeaderValue _authorization;
    private readonly string _senderAddress;

    public MailjetEmailTransport(IHttpClientFactory httpClientFactory, IOptions<EmailOptions> options)
    {
        _httpClientFactory = httpClientFactory;
        _options = options.Value;

        var apiKey = _options.MailjetApiKey ?? throw new InvalidOperationException("Thiếu Email:MailjetApiKey.");
        var secretKey = _options.MailjetSecretKey ?? throw new InvalidOperationException("Thiếu Email:MailjetSecretKey.");
        _authorization = new AuthenticationHeaderValue(
            "Basic",
            Convert.ToBase64String(Encoding.UTF8.GetBytes($"{apiKey}:{secretKey}")));

        _senderAddress = _options.SenderAddress ?? throw new InvalidOperationException("Thiếu Email:From.");
    }

    public async Task SendAsync(EmailMessage message, CancellationToken ct)
    {
        var payload = new
        {
            Messages = new[]
            {
                new
                {
                    From = new { Email = _senderAddress, Name = _options.FromName },
                    To = new[] { new { Email = message.ToAddress, Name = message.ToName } },
                    Subject = message.Subject,
                    TextPart = message.TextBody,
                    HTMLPart = message.HtmlBody
                }
            }
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, SendEndpoint)
        {
            Content = JsonContent.Create(payload, options: PayloadJson)
        };
        request.Headers.Authorization = _authorization;
        request.Headers.Accept.ParseAdd("application/json");

        using var client = _httpClientFactory.CreateClient(HttpClientName);
        using var response = await client.SendAsync(request, ct);
        var body = await response.Content.ReadAsStringAsync(ct);

        // Nội dung lỗi của Mailjet (vd. sender chưa xác minh, sai khoá) không chứa khoá, đưa vào log để chẩn đoán.
        if (!response.IsSuccessStatusCode || !IsAccepted(body))
        {
            throw new HttpRequestException(
                $"Mailjet trả về {(int)response.StatusCode}: {body}",
                inner: null,
                response.StatusCode);
        }
    }

    // Mailjet báo kết quả theo từng thư trong Messages[].Status; chỉ "success" mới là đã nhận thư.
    private static bool IsAccepted(string body)
    {
        try
        {
            using var document = JsonDocument.Parse(body);
            return document.RootElement.TryGetProperty("Messages", out var messages)
                && messages.ValueKind == JsonValueKind.Array
                && messages.GetArrayLength() > 0
                && messages.EnumerateArray().All(item =>
                    item.TryGetProperty("Status", out var status) && status.GetString() == "success");
        }
        catch (JsonException)
        {
            return false;
        }
    }
}

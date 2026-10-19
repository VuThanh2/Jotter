using System.Net;
using System.Text;
using System.Text.RegularExpressions;

namespace Jotter.Infrastructure.IntegrationTests;

// Đứng ở chỗ của generativelanguage.googleapis.com: SDK thật dựng request và đọc response thật,
// chỉ có mạng là giả. Ghi lại từng request để test kiểm cả những gì service gửi đi.
internal sealed class StubGeminiServer : HttpMessageHandler, IHttpClientFactory
{
    private readonly Func<HttpRequestMessage, HttpResponseMessage> _respond;

    public StubGeminiServer(Func<HttpRequestMessage, HttpResponseMessage> respond) => _respond = respond;

    public List<RecordedRequest> Requests { get; } = [];

    public HttpClient CreateClient(string name) => new(this, disposeHandler: false);

    public static HttpResponseMessage Json(string body, HttpStatusCode status = HttpStatusCode.OK) =>
        new(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    // Định dạng của streamGenerateContent?alt=sse: mỗi chunk là một GenerateContentResponse trên một dòng "data:".
    public static HttpResponseMessage ServerSentEvents(params string[] chunks) =>
        new(HttpStatusCode.OK)
        {
            Content = new StringContent(
                string.Concat(chunks.Select(chunk => $"data: {chunk}\r\n\r\n")),
                Encoding.UTF8,
                "text/event-stream")
        };

    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        var body = request.Content is null ? string.Empty : await request.Content.ReadAsStringAsync(ct);
        var apiKey = request.Headers.TryGetValues("x-goog-api-key", out var values) ? values.Single() : null;
        Requests.Add(new RecordedRequest(request.RequestUri!, apiKey, body));

        return _respond(request);
    }

    public sealed record RecordedRequest(Uri Uri, string? ApiKey, string Body)
    {
        // SDK escape cả dấu ngoặc nhọn lẫn chữ có dấu (\u003C, \u1EBF); bỏ escape để so khớp như văn bản thường.
        public string Text => Regex.Unescape(Body);
    }
}

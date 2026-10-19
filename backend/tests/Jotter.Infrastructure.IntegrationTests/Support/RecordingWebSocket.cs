using System.Net.WebSockets;
using System.Text;

namespace Jotter.Infrastructure.IntegrationTests;

// Socket giả chỉ ghi lại những gì server gửi xuống, để kiểm tín hiệu realtime mà không cần kết nối mạng.
internal sealed class RecordingWebSocket : WebSocket
{
    private readonly Lock _gate = new();
    private readonly List<string> _sent = [];

    public IReadOnlyList<string> Sent
    {
        get
        {
            lock (_gate)
            {
                return _sent.ToList();
            }
        }
    }

    public override WebSocketCloseStatus? CloseStatus => null;

    public override string? CloseStatusDescription => null;

    public override WebSocketState State => WebSocketState.Open;

    public override string? SubProtocol => null;

    public override Task SendAsync(
        ArraySegment<byte> buffer,
        WebSocketMessageType messageType,
        bool endOfMessage,
        CancellationToken cancellationToken)
    {
        lock (_gate)
        {
            _sent.Add(Encoding.UTF8.GetString(buffer));
        }

        return Task.CompletedTask;
    }

    public override Task<WebSocketReceiveResult> ReceiveAsync(ArraySegment<byte> buffer, CancellationToken cancellationToken) =>
        throw new NotSupportedException();

    public override Task CloseAsync(WebSocketCloseStatus closeStatus, string? statusDescription, CancellationToken cancellationToken) =>
        Task.CompletedTask;

    public override Task CloseOutputAsync(WebSocketCloseStatus closeStatus, string? statusDescription, CancellationToken cancellationToken) =>
        Task.CompletedTask;

    public override void Abort()
    {
    }

    public override void Dispose()
    {
    }
}

using System.Threading.Channels;

namespace Jotter.Infrastructure;

// Hàng đợi trong bộ nhớ giữa use case và EmailDispatcherJobService: gửi SMTP chậm hay lỗi đều không chặn request.
// Thư còn trong hàng đợi sẽ mất khi tiến trình khởi động lại — chấp nhận được vì người dùng luôn có nút "Gửi lại mã".
public sealed class EmailQueue
{
    private const int Capacity = 1_000;

    private readonly Channel<EmailMessage> _channel = Channel.CreateBounded<EmailMessage>(
        new BoundedChannelOptions(Capacity)
        {
            SingleReader = true,
            FullMode = BoundedChannelFullMode.DropWrite
        });

    // Trả false khi hàng đợi đầy; không bao giờ chờ để request không bị giữ lại vì email.
    public bool TryEnqueue(EmailMessage message) => _channel.Writer.TryWrite(message);

    public IAsyncEnumerable<EmailMessage> ReadAllAsync(CancellationToken ct) => _channel.Reader.ReadAllAsync(ct);
}

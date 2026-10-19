namespace Jotter.Infrastructure;

// Tín hiệu phát ra khi request đang nằm trong transaction (IdempotencyScope) được giữ lại tới lúc commit:
// client nhận noteChanged rồi GET ngay sẽ không đọc phải bản chưa commit, và rollback thì không phát gì cả.
public sealed class PendingRealtimeSignals
{
    private readonly List<Func<Task>> _signals = [];

    public void Enqueue(Func<Task> signal) => _signals.Add(signal);

    // Không nhận CancellationToken: dữ liệu đã commit thì tín hiệu phải được gửi dù client vừa huỷ request.
    public async Task FlushAsync()
    {
        foreach (var signal in _signals)
        {
            await signal();
        }

        _signals.Clear();
    }

    public void Discard() => _signals.Clear();
}

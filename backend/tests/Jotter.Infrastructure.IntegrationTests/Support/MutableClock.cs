namespace Jotter.Infrastructure.IntegrationTests;

// Cho phép tua thời gian để kiểm hạn phiên mở khoá, thời hạn giữ tombstone... mà không phải chờ thật.
internal sealed class MutableClock : TimeProvider
{
    private DateTimeOffset _now = DateTimeOffset.UtcNow;

    public override DateTimeOffset GetUtcNow() => _now;

    public void Advance(TimeSpan duration) => _now += duration;
}

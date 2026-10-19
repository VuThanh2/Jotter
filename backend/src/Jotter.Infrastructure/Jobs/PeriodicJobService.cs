using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Jotter.Infrastructure;

// Một lần chạy lỗi chỉ được ghi log rồi thử lại ở nhịp kế tiếp: tác vụ nền không bao giờ được làm sập ứng dụng.
public abstract class PeriodicJobService(ILogger logger) : BackgroundService
{
    protected abstract TimeSpan Interval { get; }

    protected abstract Task RunOnceAsync(CancellationToken ct);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(Interval);

        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                await RunSafelyAsync(stoppingToken);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Ứng dụng đang tắt.
        }
    }

    private async Task RunSafelyAsync(CancellationToken ct)
    {
        try
        {
            await RunOnceAsync(ct);
        }
        catch (Exception ex) when (ex is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            logger.LogError(ex, "Tác vụ nền {Job} thất bại, sẽ thử lại ở lần chạy sau.", GetType().Name);
        }
    }
}

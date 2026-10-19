using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Jotter.Infrastructure;

// Đọc liên tục EmailQueue thay vì chạy theo nhịp: thư mã OTP cần tới tay người dùng càng sớm càng tốt.
public sealed class EmailDispatcherJobService(
    EmailQueue queue,
    IEmailTransport transport,
    ILogger<EmailDispatcherJobService> logger) : BackgroundService
{
    private static readonly TimeSpan[] RetryDelays =
        [TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(30)];

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            await foreach (var message in queue.ReadAllAsync(stoppingToken))
            {
                await SendWithRetryAsync(message, stoppingToken);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Ứng dụng đang tắt.
        }
    }

    private async Task SendWithRetryAsync(EmailMessage message, CancellationToken ct)
    {
        for (var attempt = 0; ; attempt++)
        {
            try
            {
                await transport.SendAsync(message, ct);
                return;
            }
            catch (Exception ex) when (!ct.IsCancellationRequested && attempt < RetryDelays.Length)
            {
                logger.LogWarning(
                    ex,
                    "Gửi email tới {ToAddress} thất bại, thử lại lần {Attempt}.",
                    message.ToAddress,
                    attempt + 1);
                await Task.Delay(RetryDelays[attempt], ct);
            }
            catch (Exception ex) when (!ct.IsCancellationRequested)
            {
                // Bỏ thư này để không chặn hàng đợi; người dùng vẫn có nút "Gửi lại mã".
                logger.LogError(
                    ex,
                    "Bỏ email \"{Subject}\" tới {ToAddress} sau nhiều lần thất bại.",
                    message.Subject,
                    message.ToAddress);
                return;
            }
        }
    }
}

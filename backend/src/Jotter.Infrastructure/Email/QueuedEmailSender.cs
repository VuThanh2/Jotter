using Jotter.Application;
using Jotter.Domain;
using Microsoft.Extensions.Logging;

namespace Jotter.Infrastructure;

// Fire-and-forget: chỉ đưa thư vào hàng đợi rồi trả về ngay, nên SMTP lỗi không làm hỏng kết quả đăng ký hay chia sẻ.
public sealed class QueuedEmailSender(EmailQueue queue, ILogger<QueuedEmailSender> logger) : IEmailSender
{
    public Task SendActivationCodeAsync(string email, string displayName, string code, CancellationToken ct) =>
        Enqueue(EmailTemplates.ActivationCode(email, displayName, code));

    public Task SendPasswordResetCodeAsync(string email, string displayName, string code, CancellationToken ct) =>
        Enqueue(EmailTemplates.PasswordResetCode(email, displayName, code));

    public Task SendNoteSharedAsync(
        string email,
        string recipientName,
        string sharedByName,
        string noteTitle,
        SharePermission permission,
        CancellationToken ct) =>
        Enqueue(EmailTemplates.NoteShared(email, recipientName, sharedByName, noteTitle, permission));

    private Task Enqueue(EmailMessage message)
    {
        if (!queue.TryEnqueue(message))
        {
            logger.LogError(
                "Hàng đợi email đã đầy, bỏ qua thư \"{Subject}\" tới {ToAddress}.",
                message.Subject,
                message.ToAddress);
        }

        return Task.CompletedTask;
    }
}

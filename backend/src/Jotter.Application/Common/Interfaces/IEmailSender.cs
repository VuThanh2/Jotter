using Jotter.Domain;

namespace Jotter.Application;

// Chỉ đưa thư vào hàng đợi rồi trả về ngay; lỗi SMTP xảy ra ở tác vụ nền nên không làm hỏng use case.
public interface IEmailSender
{
    Task SendActivationCodeAsync(string email, string displayName, string code, CancellationToken ct);

    Task SendPasswordResetCodeAsync(string email, string displayName, string code, CancellationToken ct);

    // Không bao giờ kèm mật khẩu note.
    Task SendNoteSharedAsync(
        string email,
        string recipientName,
        string sharedByName,
        string noteTitle,
        SharePermission permission,
        CancellationToken ct);
}

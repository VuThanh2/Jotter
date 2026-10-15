using System.Net;
using Jotter.Domain;

namespace Jotter.Infrastructure;

// Mọi giá trị do người dùng nhập (tên, tiêu đề note) đều được mã hoá HTML trước khi chèn vào thư.
public static class EmailTemplates
{
    public static EmailMessage ActivationCode(string email, string displayName, string code) =>
        CodeMessage(
            email,
            displayName,
            subject: "Mã kích hoạt tài khoản Jotter",
            intro: "Cảm ơn bạn đã đăng ký Jotter. Nhập mã dưới đây trong ứng dụng để kích hoạt tài khoản:",
            code);

    public static EmailMessage PasswordResetCode(string email, string displayName, string code) =>
        CodeMessage(
            email,
            displayName,
            subject: "Mã đặt lại mật khẩu Jotter",
            intro: "Chúng tôi nhận được yêu cầu đặt lại mật khẩu. Nhập mã dưới đây trong ứng dụng để tiếp tục:",
            code,
            footnote: "Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này — mật khẩu của bạn vẫn giữ nguyên.");

    // Không bao giờ kèm mật khẩu note: chủ sở hữu tự gửi qua kênh riêng nếu note đang được bảo vệ.
    public static EmailMessage NoteShared(
        string email,
        string recipientName,
        string sharedByName,
        string noteTitle,
        SharePermission permission)
    {
        var title = string.IsNullOrWhiteSpace(noteTitle) ? "(Không có tiêu đề)" : noteTitle;
        var permissionText = permission == SharePermission.Edit ? "Chỉnh sửa" : "Chỉ đọc";
        var summary = $"{sharedByName} đã chia sẻ note \"{title}\" với bạn (quyền: {permissionText}).";

        var html = Layout(
            $"""
            <p>Xin chào {Encode(recipientName)},</p>
            <p><strong>{Encode(sharedByName)}</strong> đã chia sẻ note <strong>{Encode(title)}</strong> với bạn.</p>
            <p>Quyền của bạn: <strong>{permissionText}</strong>.</p>
            <p>Mở mục <em>Được chia sẻ với tôi</em> trong ứng dụng Jotter để xem note.</p>
            """);

        var text =
            $"""
            Xin chào {recipientName},

            {summary}
            Mở mục "Được chia sẻ với tôi" trong ứng dụng Jotter để xem note.
            """;

        return new EmailMessage(email, recipientName, $"{sharedByName} đã chia sẻ một note với bạn", html, text);
    }

    private static EmailMessage CodeMessage(
        string email,
        string displayName,
        string subject,
        string intro,
        string code,
        string? footnote = null)
    {
        var minutes = (int)VerificationCode.Lifetime.TotalMinutes;

        var html = Layout(
            $"""
            <p>Xin chào {Encode(displayName)},</p>
            <p>{intro}</p>
            <p style="font-size:28px;font-weight:bold;letter-spacing:6px;">{code}</p>
            <p>Mã có hiệu lực trong {minutes} phút và chỉ dùng được một lần.</p>
            {(footnote is null ? string.Empty : $"<p style=\"color:#666;\">{footnote}</p>")}
            """);

        var text =
            $"""
            Xin chào {displayName},

            {intro}
            {code}

            Mã có hiệu lực trong {minutes} phút và chỉ dùng được một lần.
            {footnote}
            """;

        return new EmailMessage(email, displayName, subject, html, text);
    }

    private static string Layout(string body) =>
        $"""
        <!doctype html>
        <html lang="vi">
        <body style="font-family:Arial,Helvetica,sans-serif;color:#222;line-height:1.5;">
        {body}
        <p style="color:#888;font-size:12px;">Email này được gửi tự động từ Jotter, vui lòng không trả lời.</p>
        </body>
        </html>
        """;

    private static string Encode(string value) => WebUtility.HtmlEncode(value);
}

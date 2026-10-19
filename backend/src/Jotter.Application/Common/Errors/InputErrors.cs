using Jotter.Domain;

namespace Jotter.Application;

public static class InputErrors
{
    public static readonly Error PasswordMismatch =
        Error.Validation("PasswordMismatch", "Hai lần nhập mật khẩu không khớp.");

    public static readonly Error InvalidCursor =
        Error.Validation("InvalidCursor", "Con trỏ phân trang không hợp lệ.");
}

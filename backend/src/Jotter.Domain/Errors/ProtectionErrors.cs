namespace Jotter.Domain;

public static class ProtectionErrors
{
    public static readonly Error AlreadyProtected =
        Error.Conflict("AlreadyProtected", "Note đã được bảo vệ bằng mật khẩu.");

    public static readonly Error NotProtected =
        Error.Conflict("NotProtected", "Note chưa được bảo vệ bằng mật khẩu.");

    public static readonly Error InvalidNotePassword =
        Error.Validation("InvalidNotePassword", "Mật khẩu note không đúng.");

    public static readonly Error PasswordTooWeak =
        Error.Validation("PasswordTooWeak", $"Mật khẩu note phải có ít nhất {NotePassword.MinLength} ký tự.");

    public static readonly Error TooManyAttempts =
        Error.TooManyRequests("TooManyAttempts", "Nhập sai mật khẩu note quá nhiều lần. Vui lòng thử lại sau.");
}

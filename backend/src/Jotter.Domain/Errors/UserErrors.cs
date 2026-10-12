namespace Jotter.Domain;

public static class UserErrors
{
    public static readonly Error NotFound =
        Error.NotFound("UserNotFound", "Không tìm thấy tài khoản.");

    public static readonly Error EmailAlreadyExists =
        Error.Conflict("EmailAlreadyExists", "Email này đã được dùng để đăng ký.");

    public static readonly Error InvalidCredentials =
        Error.Unauthorized("InvalidCredentials", "Email hoặc mật khẩu không đúng.");

    public static readonly Error AccountLockedOut =
        Error.TooManyRequests("AccountLockedOut", "Tài khoản tạm bị khoá do đăng nhập sai quá nhiều lần.");

    public static readonly Error PasswordTooWeak =
        Error.Validation("PasswordTooWeak", "Mật khẩu chưa đáp ứng chính sách độ phức tạp.");

    public static readonly Error SamePassword =
        Error.Validation("SamePassword", "Mật khẩu mới phải khác mật khẩu hiện tại.");

    public static readonly Error InvalidCurrentPassword =
        Error.Validation("InvalidCurrentPassword", "Mật khẩu hiện tại không đúng.");

    public static readonly Error AlreadyActivated =
        Error.Conflict("AlreadyActivated", "Tài khoản đã được kích hoạt.");

    public static readonly Error DisplayNameRequired =
        Error.Validation("DisplayNameRequired", "Tên hiển thị không được để trống.");

    public static readonly Error DisplayNameTooLong =
        Error.Validation("DisplayNameTooLong", $"Tên hiển thị tối đa {DisplayName.MaxLength} ký tự.");

    public static readonly Error InvalidNoteFontSize =
        Error.Validation(
            "InvalidNoteFontSize",
            $"Cỡ chữ phải nằm trong khoảng {UserPreferences.MinNoteFontSize}–{UserPreferences.MaxNoteFontSize}.");

    public static readonly Error InvalidNoteColor =
        Error.Validation("InvalidNoteColor", "Màu note phải có dạng #RRGGBB.");

    public static readonly Error InvalidThemeMode =
        Error.Validation("InvalidThemeMode", "Chế độ giao diện không hợp lệ.");

    public static readonly Error InvalidListViewMode =
        Error.Validation("InvalidListViewMode", "Kiểu hiển thị danh sách không hợp lệ.");
}

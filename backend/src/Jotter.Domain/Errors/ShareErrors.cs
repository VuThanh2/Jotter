namespace Jotter.Domain;

public static class ShareErrors
{
    public static readonly Error NotFound =
        Error.NotFound("ShareNotFound", "Không tìm thấy lượt chia sẻ.");

    public static readonly Error CannotShareWithSelf =
        Error.Validation("CannotShareWithSelf", "Không thể chia sẻ note cho chính mình.");

    public static readonly Error DuplicateShare =
        Error.Conflict("DuplicateShare", "Người này đã được chia sẻ note.");

    public static readonly Error RecipientNotRegistered =
        Error.Validation("RecipientNotRegistered", "Email người nhận chưa đăng ký tài khoản.");

    public static readonly Error InvalidPermission =
        Error.Validation("InvalidPermission", "Mức quyền chia sẻ không hợp lệ.");
}

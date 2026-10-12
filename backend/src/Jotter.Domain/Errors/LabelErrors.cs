namespace Jotter.Domain;

public static class LabelErrors
{
    public static readonly Error NotFound =
        Error.NotFound("LabelNotFound", "Không tìm thấy nhãn.");

    public static readonly Error InvalidId =
        Error.Validation("InvalidLabelId", "Định danh nhãn không hợp lệ.");

    public static readonly Error IdAlreadyExists =
        Error.Conflict("LabelIdAlreadyExists", "Định danh nhãn đã tồn tại.");

    public static readonly Error DuplicateName =
        Error.Conflict("DuplicateLabelName", "Bạn đã có nhãn trùng tên.");

    public static readonly Error NameRequired =
        Error.Validation("LabelNameRequired", "Tên nhãn không được để trống.");

    public static readonly Error NameTooLong =
        Error.Validation("LabelNameTooLong", $"Tên nhãn tối đa {LabelName.MaxLength} ký tự.");
}

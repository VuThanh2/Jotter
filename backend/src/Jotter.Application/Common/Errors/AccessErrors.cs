using Jotter.Domain;

namespace Jotter.Application;

// "Không thấy note" dùng lại NoteErrors.NotFound của Domain để mã NoteNotFound chỉ có một định nghĩa.
public static class AccessErrors
{
    public static readonly Error Forbidden =
        Error.Forbidden("Forbidden", "Bạn không có quyền thực hiện thao tác này.");

    public static readonly Error NoteLocked =
        Error.Locked("NoteLocked", "Note đang được bảo vệ. Vui lòng mở khoá trước.");
}

namespace Jotter.Domain;

public static class FileErrors
{
    public static readonly Error UnsupportedMediaType =
        Error.Validation("UnsupportedMediaType", "Định dạng tệp không được hỗ trợ.");

    public static readonly Error FileTooLarge =
        Error.Validation("FileTooLarge", "Tệp vượt quá dung lượng cho phép.");

    public static readonly Error EmptyFile =
        Error.Validation("EmptyFile", "Tệp không có nội dung.");

    public static readonly Error InvalidFileName =
        Error.Validation("InvalidFileName", $"Tên tệp không hợp lệ hoặc dài quá {Attachment.MaxFileNameLength} ký tự.");
}

namespace Jotter.Domain;

public static class NoteErrors
{
    public static readonly Error NotFound =
        Error.NotFound("NoteNotFound", "Không tìm thấy note.");

    public static readonly Error InvalidId =
        Error.Validation("InvalidNoteId", "Định danh note không hợp lệ.");

    public static readonly Error IdAlreadyExists =
        Error.Conflict("NoteIdAlreadyExists", "Định danh note đã tồn tại.");

    public static readonly Error InvalidConflictSource =
        Error.Validation("InvalidConflictSource", "Note gốc của bản sao xung đột không hợp lệ.");

    public static readonly Error EmptyNote =
        Error.Validation("EmptyNote", "Note phải có tiêu đề hoặc nội dung.");

    public static readonly Error TitleTooLong =
        Error.Validation("NoteTitleTooLong", $"Tiêu đề tối đa {NoteTitle.MaxLength} ký tự.");

    public static readonly Error ContentTooLong =
        Error.Validation("NoteContentTooLong", $"Nội dung tối đa {NoteContent.MaxLength} ký tự.");

    public static readonly Error VersionConflict =
        Error.Conflict("VersionConflict", "Note đã được thay đổi ở nơi khác.");

    public static readonly Error EmptyContent =
        Error.Validation("EmptyContent", "Note chưa có nội dung để tóm tắt.");

    public static readonly Error EmptySummary =
        Error.Validation("EmptySummary", "Bản tóm tắt không được rỗng.");

    public static readonly Error SummaryNotFound =
        Error.NotFound("SummaryNotFound", "Note chưa có bản tóm tắt.");

    public static readonly Error AttachmentNotFound =
        Error.NotFound("AttachmentNotFound", "Không tìm thấy tệp đính kèm.");
}

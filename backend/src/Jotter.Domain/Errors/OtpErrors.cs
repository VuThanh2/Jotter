namespace Jotter.Domain;

public static class OtpErrors
{
    public static readonly Error InvalidCode =
        Error.Validation("InvalidCode", "Mã xác minh không đúng.");

    public static readonly Error CodeExpired =
        Error.Validation("CodeExpired", "Mã xác minh đã hết hạn. Vui lòng yêu cầu mã mới.");

    public static readonly Error TooManyAttempts =
        Error.TooManyRequests("TooManyAttempts", "Nhập sai quá nhiều lần. Vui lòng yêu cầu mã mới.");

    public static readonly Error ResendTooSoon =
        Error.TooManyRequests("TooManyRequests", "Vui lòng chờ trước khi yêu cầu gửi lại mã.");

    public static readonly Error InvalidResetTicket =
        Error.Validation("InvalidResetTicket", "Phiên đặt lại mật khẩu không hợp lệ.");

    public static readonly Error TicketExpired =
        Error.Validation("TicketExpired", "Phiên đặt lại mật khẩu đã hết hạn. Vui lòng thực hiện lại.");
}

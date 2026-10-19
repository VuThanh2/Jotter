namespace Jotter.Application;

// Không nhận lại email hay code: danh tính nằm trong resetTicket, nhận lại là mở đường bỏ qua bước xác minh.
public sealed record ResetPasswordInputDto(string ResetTicket, string NewPassword, string ConfirmPassword);

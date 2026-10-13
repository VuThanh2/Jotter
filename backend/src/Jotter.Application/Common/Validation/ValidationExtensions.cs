using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public static class ValidationExtensions
{
    // Giới hạn cột email mặc định của Identity.
    public const int MaxEmailLength = 256;

    private static readonly string OtpCodePattern = $"^[0-9]{{{IOtpService.CodeLength}}}$";

    public static IRuleBuilderOptions<T, TProperty> WithError<T, TProperty>(
        this IRuleBuilderOptions<T, TProperty> rule,
        Error error) =>
        rule.WithErrorCode(error.Code).WithMessage(error.Message);

    public static IRuleBuilderOptions<T, string> ValidEmail<T>(this IRuleBuilder<T, string> rule) =>
        rule.NotEmpty().EmailAddress().MaximumLength(MaxEmailLength);

    public static IRuleBuilderOptions<T, string> ValidDisplayName<T>(this IRuleBuilder<T, string> rule) =>
        rule.NotEmpty().WithError(UserErrors.DisplayNameRequired)
            .MaximumLength(DisplayName.MaxLength).WithError(UserErrors.DisplayNameTooLong);

    public static IRuleBuilderOptions<T, string> ValidOtpCode<T>(this IRuleBuilder<T, string> rule) =>
        rule.NotEmpty().Matches(OtpCodePattern).WithError(OtpErrors.InvalidCode);

    // Độ dài mật khẩu note kiểm ở đây vì nó không đi qua PasswordValidator của Identity.
    public static IRuleBuilderOptions<T, string> ValidNotePassword<T>(this IRuleBuilder<T, string> rule) =>
        rule.NotEmpty()
            .MinimumLength(NotePassword.MinLength).WithError(ProtectionErrors.PasswordTooWeak)
            .MaximumLength(NotePassword.MaxLength);

    public static IRuleBuilderOptions<T, string?> ValidCursor<T>(this IRuleBuilder<T, string?> rule) =>
        rule.MaximumLength(512).WithError(InputErrors.InvalidCursor);
}

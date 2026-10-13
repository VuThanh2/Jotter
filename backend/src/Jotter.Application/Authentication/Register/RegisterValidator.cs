using FluentValidation;

namespace Jotter.Application;

// Độ phức tạp mật khẩu do PasswordValidator của Identity kiểm, không lặp lại ở đây.
public sealed class RegisterValidator : AbstractValidator<RegisterInputDto>
{
    public RegisterValidator()
    {
        RuleFor(x => x.Email).ValidEmail();
        RuleFor(x => x.DisplayName).ValidDisplayName();
        RuleFor(x => x.Password).NotEmpty();
        RuleFor(x => x.ConfirmPassword).Equal(x => x.Password).WithError(InputErrors.PasswordMismatch);
    }
}

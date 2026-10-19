using FluentValidation;

namespace Jotter.Application;

public sealed class ChangePasswordValidator : AbstractValidator<ChangePasswordInputDto>
{
    public ChangePasswordValidator()
    {
        RuleFor(x => x.CurrentPassword).NotEmpty();
        RuleFor(x => x.NewPassword).NotEmpty();
        RuleFor(x => x.ConfirmPassword).Equal(x => x.NewPassword).WithError(InputErrors.PasswordMismatch);
    }
}

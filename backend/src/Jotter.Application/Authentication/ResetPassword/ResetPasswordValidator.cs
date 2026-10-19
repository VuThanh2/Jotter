using FluentValidation;

namespace Jotter.Application;

public sealed class ResetPasswordValidator : AbstractValidator<ResetPasswordInputDto>
{
    public ResetPasswordValidator()
    {
        RuleFor(x => x.ResetTicket).NotEmpty();
        RuleFor(x => x.NewPassword).NotEmpty();
        RuleFor(x => x.ConfirmPassword).Equal(x => x.NewPassword).WithError(InputErrors.PasswordMismatch);
    }
}

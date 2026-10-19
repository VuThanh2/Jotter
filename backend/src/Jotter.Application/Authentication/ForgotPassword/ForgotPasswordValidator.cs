using FluentValidation;

namespace Jotter.Application;

public sealed class ForgotPasswordValidator : AbstractValidator<ForgotPasswordInputDto>
{
    public ForgotPasswordValidator()
    {
        RuleFor(x => x.Email).ValidEmail();
    }
}

using FluentValidation;

namespace Jotter.Application;

public sealed class VerifyResetCodeValidator : AbstractValidator<VerifyResetCodeInputDto>
{
    public VerifyResetCodeValidator()
    {
        RuleFor(x => x.Email).ValidEmail();
        RuleFor(x => x.Code).ValidOtpCode();
    }
}

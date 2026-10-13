using FluentValidation;

namespace Jotter.Application;

public sealed class ConfirmActivationValidator : AbstractValidator<ConfirmActivationInputDto>
{
    public ConfirmActivationValidator()
    {
        RuleFor(x => x.Code).ValidOtpCode();
    }
}

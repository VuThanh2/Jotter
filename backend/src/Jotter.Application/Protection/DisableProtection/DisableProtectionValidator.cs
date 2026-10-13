using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class DisableProtectionValidator : AbstractValidator<DisableProtectionInputDto>
{
    public DisableProtectionValidator()
    {
        RuleFor(x => x.CurrentPassword).NotEmpty().MaximumLength(NotePassword.MaxLength);
    }
}

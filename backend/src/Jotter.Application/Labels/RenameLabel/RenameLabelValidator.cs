using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class RenameLabelValidator : AbstractValidator<RenameLabelInputDto>
{
    public RenameLabelValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithError(LabelErrors.NameRequired)
            .MaximumLength(LabelName.MaxLength).WithError(LabelErrors.NameTooLong);
    }
}

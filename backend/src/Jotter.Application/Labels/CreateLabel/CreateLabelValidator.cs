using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class CreateLabelValidator : AbstractValidator<CreateLabelInputDto>
{
    public CreateLabelValidator()
    {
        RuleFor(x => x.LabelId).NotEmpty().WithError(LabelErrors.InvalidId);
        RuleFor(x => x.Name)
            .NotEmpty().WithError(LabelErrors.NameRequired)
            .MaximumLength(LabelName.MaxLength).WithError(LabelErrors.NameTooLong);
    }
}

using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class SetNoteLabelsValidator : AbstractValidator<SetNoteLabelsInputDto>
{
    public const int MaxLabelsPerNote = 50;

    public SetNoteLabelsValidator()
    {
        RuleFor(x => x.LabelIds).NotNull().Must(ids => ids is null || ids.Count <= MaxLabelsPerNote);
        RuleForEach(x => x.LabelIds).NotEmpty().WithError(LabelErrors.InvalidId);
    }
}

using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class UpdateNoteContentValidator : AbstractValidator<UpdateNoteContentInputDto>
{
    public UpdateNoteContentValidator()
    {
        RuleFor(x => x.BaseVersion).GreaterThanOrEqualTo(0);
        RuleFor(x => x.Title).MaximumLength(NoteTitle.MaxLength).WithError(NoteErrors.TitleTooLong);
        RuleFor(x => x.Content).MaximumLength(NoteContent.MaxLength).WithError(NoteErrors.ContentTooLong);
    }
}

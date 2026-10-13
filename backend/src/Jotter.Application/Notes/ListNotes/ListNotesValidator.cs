using FluentValidation;

namespace Jotter.Application;

public sealed class ListNotesValidator : AbstractValidator<ListNotesInputDto>
{
    public const int MaxQueryLength = 200;
    public const int MaxLabelFilters = 50;

    public ListNotesValidator()
    {
        RuleFor(x => x.Q).MaximumLength(MaxQueryLength);
        RuleFor(x => x.Scope).IsInEnum();
        RuleFor(x => x.LabelIds).Must(ids => ids is null || ids.Length <= MaxLabelFilters);
        RuleForEach(x => x.LabelIds).NotEmpty();
        RuleFor(x => x.Cursor).ValidCursor();
        RuleFor(x => x.Limit).InclusiveBetween(1, ListNotesQuery.MaxLimit);
    }
}

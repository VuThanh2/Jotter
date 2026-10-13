using FluentValidation;

namespace Jotter.Application;

public sealed class ListSharedWithMeValidator : AbstractValidator<ListSharedWithMeInputDto>
{
    public ListSharedWithMeValidator()
    {
        RuleFor(x => x.Cursor).ValidCursor();
        RuleFor(x => x.Limit).InclusiveBetween(1, ListSharedWithMeQuery.MaxLimit);
    }
}

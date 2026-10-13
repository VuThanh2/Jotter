using FluentValidation;

namespace Jotter.Application;

public sealed class PullChangesValidator : AbstractValidator<PullChangesInputDto>
{
    public PullChangesValidator()
    {
        RuleFor(x => x.Since).GreaterThanOrEqualTo(0);
        RuleFor(x => x.Limit).InclusiveBetween(1, PullChangesQuery.MaxLimit);
    }
}

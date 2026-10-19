using FluentValidation;

namespace Jotter.Application;

public sealed class UpdateProfileValidator : AbstractValidator<UpdateProfileInputDto>
{
    public UpdateProfileValidator()
    {
        RuleFor(x => x.DisplayName).ValidDisplayName();
    }
}

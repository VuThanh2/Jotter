using FluentValidation;

namespace Jotter.Application;

public sealed class LoginValidator : AbstractValidator<LoginInputDto>
{
    public LoginValidator()
    {
        RuleFor(x => x.Email).ValidEmail();
        RuleFor(x => x.Password).NotEmpty();
    }
}

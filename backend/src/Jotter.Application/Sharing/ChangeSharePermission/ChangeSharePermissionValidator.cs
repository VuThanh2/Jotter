using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class ChangeSharePermissionValidator : AbstractValidator<ChangeSharePermissionInputDto>
{
    public ChangeSharePermissionValidator()
    {
        RuleFor(x => x.Permission).IsInEnum().WithError(ShareErrors.InvalidPermission);
    }
}

using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class ChangeNotePasswordValidator : AbstractValidator<ChangeNotePasswordInputDto>
{
    public ChangeNotePasswordValidator()
    {
        RuleFor(x => x.CurrentPassword).NotEmpty().MaximumLength(NotePassword.MaxLength);
        RuleFor(x => x.NewPassword).ValidNotePassword();
        RuleFor(x => x.ConfirmPassword).Equal(x => x.NewPassword).WithError(InputErrors.PasswordMismatch);
    }
}

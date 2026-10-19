using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class UnlockNoteValidator : AbstractValidator<UnlockNoteInputDto>
{
    public UnlockNoteValidator()
    {
        RuleFor(x => x.Password).NotEmpty().MaximumLength(NotePassword.MaxLength);
    }
}

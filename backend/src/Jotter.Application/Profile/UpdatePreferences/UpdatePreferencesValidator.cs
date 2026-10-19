using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class UpdatePreferencesValidator : AbstractValidator<UpdatePreferencesInputDto>
{
    public UpdatePreferencesValidator()
    {
        RuleFor(x => x.NoteFontSize)
            .InclusiveBetween(UserPreferences.MinNoteFontSize, UserPreferences.MaxNoteFontSize)
            .WithError(UserErrors.InvalidNoteFontSize);

        RuleFor(x => x.DefaultNoteColor)
            .Must(UserPreferences.IsValidNoteColor)
            .WithError(UserErrors.InvalidNoteColor);

        RuleFor(x => x.ThemeMode).IsInEnum().WithError(UserErrors.InvalidThemeMode);
        RuleFor(x => x.ListViewMode).IsInEnum().WithError(UserErrors.InvalidListViewMode);
    }
}

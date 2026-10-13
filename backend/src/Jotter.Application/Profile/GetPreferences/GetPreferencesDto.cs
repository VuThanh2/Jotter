using Jotter.Domain;

namespace Jotter.Application;

public sealed record GetPreferencesOutputDto(
    int NoteFontSize,
    string DefaultNoteColor,
    ThemeMode ThemeMode,
    ListViewMode ListViewMode);

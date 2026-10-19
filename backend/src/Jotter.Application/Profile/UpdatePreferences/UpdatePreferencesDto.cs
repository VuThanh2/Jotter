using Jotter.Domain;

namespace Jotter.Application;

public sealed record UpdatePreferencesInputDto(
    int NoteFontSize,
    string DefaultNoteColor,
    ThemeMode ThemeMode,
    ListViewMode ListViewMode);

public sealed record UpdatePreferencesOutputDto(
    int NoteFontSize,
    string DefaultNoteColor,
    ThemeMode ThemeMode,
    ListViewMode ListViewMode);

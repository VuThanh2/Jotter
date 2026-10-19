namespace Jotter.Domain;

public sealed class UserPreferences
{
    public const int MinNoteFontSize = 12;
    public const int MaxNoteFontSize = 32;
    public const int InitialNoteFontSize = 16;
    public const string InitialNoteColor = "#FFFFFF";

    private UserPreferences()
    {
    }

    private UserPreferences(Guid userId)
    {
        UserId = userId;
        NoteFontSize = InitialNoteFontSize;
        DefaultNoteColor = InitialNoteColor;
        ThemeMode = ThemeMode.System;
        ListViewMode = ListViewMode.Grid;
    }

    public Guid UserId { get; private init; }

    public int NoteFontSize { get; private set; }

    public string DefaultNoteColor { get; private set; } = InitialNoteColor;

    public ThemeMode ThemeMode { get; private set; }

    public ListViewMode ListViewMode { get; private set; }

    public static bool IsValidNoteColor(string? color) =>
        color is { Length: 7 } && color[0] == '#' && color.Skip(1).All(char.IsAsciiHexDigit);

    internal static UserPreferences CreateDefault(Guid userId) => new(userId);

    internal Result Update(int noteFontSize, string? defaultNoteColor, ThemeMode themeMode, ListViewMode listViewMode)
    {
        if (noteFontSize is < MinNoteFontSize or > MaxNoteFontSize)
        {
            return UserErrors.InvalidNoteFontSize;
        }

        if (!IsValidNoteColor(defaultNoteColor))
        {
            return UserErrors.InvalidNoteColor;
        }

        if (!Enum.IsDefined(themeMode))
        {
            return UserErrors.InvalidThemeMode;
        }

        if (!Enum.IsDefined(listViewMode))
        {
            return UserErrors.InvalidListViewMode;
        }

        NoteFontSize = noteFontSize;
        DefaultNoteColor = defaultNoteColor!.ToUpperInvariant();
        ThemeMode = themeMode;
        ListViewMode = listViewMode;

        return Result.Success();
    }
}

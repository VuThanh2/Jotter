using Xunit;

namespace Jotter.Domain.UnitTests;

public sealed class UserTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 12, 8, 0, 0, TimeSpan.Zero);

    [Fact]
    public void Create_UsesEmailAsUserName_AndDefaultPreferences()
    {
        var user = User.Create(" an@example.com ", "  Nguyễn Văn An ", Now).Value;

        Assert.Equal("an@example.com", user.UserName);
        Assert.Equal("an@example.com", user.Email);
        Assert.Equal("Nguyễn Văn An", user.DisplayName);
        Assert.Equal(user.Id, user.Preferences.UserId);
        Assert.Equal(ListViewMode.Grid, user.Preferences.ListViewMode);
        Assert.Equal(ThemeMode.System, user.Preferences.ThemeMode);
    }

    [Fact]
    public void UpdatePreferences_ValidatesEveryField()
    {
        var user = User.Create("a@b.c", "A", Now).Value;

        Assert.Equal(UserErrors.InvalidNoteFontSize,
            user.UpdatePreferences(UserPreferences.MaxNoteFontSize + 1, "#FFFFFF", ThemeMode.Dark, ListViewMode.List).Error);
        Assert.Equal(UserErrors.InvalidNoteColor,
            user.UpdatePreferences(16, "red", ThemeMode.Dark, ListViewMode.List).Error);
        Assert.Equal(UserErrors.InvalidThemeMode,
            user.UpdatePreferences(16, "#FFFFFF", (ThemeMode)9, ListViewMode.List).Error);

        Assert.True(user.UpdatePreferences(18, "#ffcc00", ThemeMode.Dark, ListViewMode.List).IsSuccess);
        Assert.Equal("#FFCC00", user.Preferences.DefaultNoteColor);
    }

    [Fact]
    public void UpdateDisplayName_RejectsBlank()
    {
        var user = User.Create("a@b.c", "A", Now).Value;

        Assert.Equal(UserErrors.DisplayNameRequired, user.UpdateDisplayName("   ").Error);
        Assert.Equal("A", user.DisplayName);
    }
}

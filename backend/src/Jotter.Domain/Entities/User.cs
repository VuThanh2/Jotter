using System.Collections.Frozen;
using Microsoft.AspNetCore.Identity;

namespace Jotter.Domain;

// Email, PasswordHash, SecurityStamp, EmailConfirmed thuộc Identity và chỉ được ghi qua UserManager.
public sealed class User : IdentityUser<Guid>, IAggregateRoot
{
    public const long MaxAvatarSizeBytes = 5L * 1024 * 1024;

    public static readonly FrozenSet<string> AvatarMimeTypes =
        new[] { "image/jpeg", "image/png", "image/webp" }.ToFrozenSet(StringComparer.OrdinalIgnoreCase);

    private User()
    {
    }

    private User(string email, DisplayName displayName, DateTimeOffset now)
    {
        Id = Guid.CreateVersion7(now);
        UserName = email;
        Email = email;
        DisplayName = displayName.Value;
        CreatedAt = now;
        Preferences = UserPreferences.CreateDefault(Id);
    }

    public string DisplayName { get; private set; } = string.Empty;

    public string? AvatarStorageKey { get; private set; }

    public DateTimeOffset CreatedAt { get; private init; }

    public UserPreferences Preferences { get; private set; } = null!;

    // UserName = email vì UserName của Identity không nhận tiếng Việt có dấu và khoảng trắng.
    public static Result<User> Create(string email, string? displayName, DateTimeOffset now)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(email);

        var nameResult = Jotter.Domain.DisplayName.Create(displayName);
        if (nameResult.IsFailure)
        {
            return nameResult.Error;
        }

        return new User(email.Trim(), nameResult.Value, now);
    }

    public Result UpdateDisplayName(string? displayName)
    {
        var nameResult = Jotter.Domain.DisplayName.Create(displayName);
        if (nameResult.IsFailure)
        {
            return nameResult.Error;
        }

        DisplayName = nameResult.Value.Value;

        return Result.Success();
    }

    public void SetAvatar(string storageKey)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(storageKey);
        AvatarStorageKey = storageKey;
    }

    public void RemoveAvatar() => AvatarStorageKey = null;

    public Result UpdatePreferences(
        int noteFontSize,
        string? defaultNoteColor,
        ThemeMode themeMode,
        ListViewMode listViewMode) =>
        Preferences.Update(noteFontSize, defaultNoteColor, themeMode, listViewMode);
}

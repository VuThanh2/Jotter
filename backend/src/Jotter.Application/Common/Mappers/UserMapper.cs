using System.Security.Cryptography;
using System.Text;
using Jotter.Domain;

namespace Jotter.Application;

public static class UserMapper
{
    public static UserDto ToUserDto(User user) =>
        new(user.Id, user.Email!, user.DisplayName, user.EmailConfirmed, ToAvatarUrl(user));

    public static RegisterOutputDto ToRegisterOutputDto(User user, IssuedToken token) =>
        new(token.Value, token.ExpiresAt, ToUserDto(user));

    public static LoginOutputDto ToLoginOutputDto(User user, IssuedToken token) =>
        new(token.Value, token.ExpiresAt, ToUserDto(user));

    public static ConfirmActivationOutputDto ToConfirmActivationOutputDto(User user, IssuedToken token) =>
        new(user.EmailConfirmed, token.Value, token.ExpiresAt);

    public static GetMeOutputDto ToGetMeOutputDto(User user) =>
        new(user.Id, user.Email!, user.DisplayName, ToAvatarUrl(user), user.EmailConfirmed, user.CreatedAt);

    public static UpdateProfileOutputDto ToUpdateProfileOutputDto(User user) =>
        new(user.Id, user.Email!, user.DisplayName, ToAvatarUrl(user), user.EmailConfirmed);

    public static UploadAvatarOutputDto ToUploadAvatarOutputDto(User user) =>
        new(BuildAvatarUrl(user.Id, user.AvatarStorageKey!));

    public static GetPreferencesOutputDto ToGetPreferencesOutputDto(UserPreferences preferences) =>
        new(preferences.NoteFontSize, preferences.DefaultNoteColor, preferences.ThemeMode, preferences.ListViewMode);

    public static UpdatePreferencesOutputDto ToUpdatePreferencesOutputDto(UserPreferences preferences) =>
        new(preferences.NoteFontSize, preferences.DefaultNoteColor, preferences.ThemeMode, preferences.ListViewMode);

    private static string? ToAvatarUrl(User user) =>
        user.AvatarStorageKey is { } storageKey ? BuildAvatarUrl(user.Id, storageKey) : null;

    // Ảnh được phục vụ qua GetAvatarQuery. Tham số v đổi theo mỗi lần tải ảnh mới để client không dùng lại ảnh cũ trong cache,
    // và là hash để không lộ storageKey ra ngoài.
    private static string BuildAvatarUrl(Guid userId, string storageKey)
    {
        var fingerprint = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(storageKey)))[..12];
        return $"/api/users/{userId}/avatar?v={fingerprint}";
    }
}

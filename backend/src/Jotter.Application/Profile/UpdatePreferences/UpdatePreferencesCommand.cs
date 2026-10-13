using Jotter.Domain;

namespace Jotter.Application;

public sealed class UpdatePreferencesCommand(ICurrentUser currentUser, IUserRepository users, IUnitOfWork unitOfWork)
{
    public async Task<Result<UpdatePreferencesOutputDto>> ExecuteAsync(
        UpdatePreferencesInputDto input,
        CancellationToken ct)
    {
        var user = await users.GetByIdAsync(currentUser.UserId, ct);
        if (user is null)
        {
            return UserErrors.NotFound;
        }

        var updated = user.UpdatePreferences(
            input.NoteFontSize,
            input.DefaultNoteColor,
            input.ThemeMode,
            input.ListViewMode);

        if (updated.IsFailure)
        {
            return updated.Error;
        }

        await unitOfWork.SaveChangesAsync(ct);

        return UserMapper.ToUpdatePreferencesOutputDto(user.Preferences);
    }
}

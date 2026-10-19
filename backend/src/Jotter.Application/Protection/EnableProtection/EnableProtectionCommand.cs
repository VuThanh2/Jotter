using Jotter.Domain;

namespace Jotter.Application;

public sealed class EnableProtectionCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    INotePasswordHasher passwordHasher,
    IUnitOfWork unitOfWork)
{
    public async Task<Result<EnableProtectionOutputDto>> ExecuteAsync(
        Guid noteId,
        EnableProtectionInputDto input,
        CancellationToken ct)
    {
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureOwner();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var note = await notes.GetByIdAsync(noteId, ct);
        if (note is null)
        {
            return NoteErrors.NotFound;
        }

        var enabled = note.EnableProtection(passwordHasher.Hash(input.Password));
        if (enabled.IsFailure)
        {
            return enabled.Error;
        }

        await unitOfWork.SaveChangesAsync(ct);

        return NoteMapper.ToEnableProtectionOutputDto(note);
    }
}

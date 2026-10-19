using Jotter.Domain;

namespace Jotter.Application;

public sealed class PinNoteCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    // Ghim là trạng thái riêng của chủ sở hữu, không tăng Version nên không gây xung đột giả cho editor đang mở.
    public async Task<Result<PinNoteOutputDto>> ExecuteAsync(Guid noteId, PinNoteInputDto input, CancellationToken ct)
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

        var pinned = input.IsPinned ? note.Pin(clock.GetUtcNow()) : note.Unpin();
        if (pinned.IsFailure)
        {
            return pinned.Error;
        }

        await unitOfWork.SaveChangesAsync(ct);

        return NoteMapper.ToPinNoteOutputDto(note);
    }
}

using Jotter.Domain;

namespace Jotter.Application;

public sealed class SetNoteLabelsCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    ILabelRepository labels,
    IUnitOfWork unitOfWork)
{
    public async Task<Result<SetNoteLabelsOutputDto>> ExecuteAsync(
        Guid noteId,
        SetNoteLabelsInputDto input,
        CancellationToken ct)
    {
        // Nhãn là cách tổ chức riêng của từng người nên chỉ chủ sở hữu được gắn.
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

        var labelIds = input.LabelIds.Distinct().ToList();

        // Bất biến xuyên Aggregate: Note chỉ được gắn nhãn còn sống của chính chủ sở hữu note.
        if (!await labels.AreAllActiveAndOwnedByAsync(note.OwnerId, labelIds, ct))
        {
            return LabelErrors.NotFound;
        }

        var labeled = note.SetLabels(labelIds);
        if (labeled.IsFailure)
        {
            return labeled.Error;
        }

        await unitOfWork.SaveChangesAsync(ct);

        return NoteMapper.ToSetNoteLabelsOutputDto(note);
    }
}

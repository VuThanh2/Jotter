using Jotter.Domain;

namespace Jotter.Application;

public sealed class CreateNoteCommand(
    ICurrentUser currentUser,
    INoteRepository notes,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result<CreateNoteOutputDto>> ExecuteAsync(CreateNoteInputDto input, CancellationToken ct)
    {
        // noteId do client sinh: không được tái sử dụng, kể cả id của note đã xoá.
        if (await notes.ExistsAsync(input.NoteId, ct))
        {
            return NoteErrors.IdAlreadyExists;
        }

        // ownerId luôn là người gọi — với Conflict Copy, đó chính là người vừa soạn nội dung bị từ chối.
        var now = clock.GetUtcNow();
        var created = input.ConflictOfNoteId is { } sourceNoteId
            ? Note.CreateConflictCopy(input.NoteId, currentUser.UserId, sourceNoteId, input.Title, input.Content, now)
            : Note.Create(input.NoteId, currentUser.UserId, input.Title, input.Content, now);

        if (created.IsFailure)
        {
            return created.Error;
        }

        notes.Add(created.Value);

        await unitOfWork.SaveChangesAsync(ct);

        return NoteMapper.ToCreateNoteOutputDto(created.Value);
    }
}

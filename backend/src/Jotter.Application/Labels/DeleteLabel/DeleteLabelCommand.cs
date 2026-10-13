using Jotter.Domain;

namespace Jotter.Application;

public sealed class DeleteLabelCommand(
    ICurrentUser currentUser,
    ILabelRepository labels,
    INoteRepository notes,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    public async Task<Result> ExecuteAsync(Guid labelId, CancellationToken ct)
    {
        var label = await labels.GetByIdAsync(labelId, ct);
        if (label is null || label.IsDeleted)
        {
            return LabelErrors.NotFound;
        }

        if (label.OwnerId != currentUser.UserId)
        {
            return AccessErrors.Forbidden;
        }

        // Ngoại lệ có ý thức: thao tác duy nhất chạm nhiều Note Aggregate trong một transaction.
        // Chấp nhận được vì là monolith một database; mỗi note bị gỡ nhãn được cấp changeSeq mới để lan tới thiết bị khác.
        var labeledNotes = await notes.ListByLabelAsync(label.Id, ct);

        var deleted = label.MarkDeleted(clock.GetUtcNow());
        if (deleted.IsFailure)
        {
            return deleted;
        }

        foreach (var note in labeledNotes)
        {
            note.DetachLabel(label.Id);
        }

        await unitOfWork.SaveChangesAsync(ct);

        return Result.Success();
    }
}

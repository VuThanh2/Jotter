using Jotter.Domain;

namespace Jotter.Application;

public sealed class UpdateNoteContentCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    INoteUnlockSessionRepository unlockSessions,
    IUnitOfWork unitOfWork,
    IRealtimeNotifier realtime,
    TimeProvider clock)
{
    public async Task<Result<UpdateNoteContentOutputDto>> ExecuteAsync(
        Guid noteId,
        UpdateNoteContentInputDto input,
        CancellationToken ct)
    {
        // ReadOnly bị chặn ở đây, không phải bằng cách ẩn nút trên UI.
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureCanEditContent();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var note = await notes.GetByIdAsync(noteId, ct);
        if (note is null)
        {
            return NoteErrors.NotFound;
        }

        var now = clock.GetUtcNow();
        var unlockSessionsToExtend = access.IsProtected
            ? await unlockSessions.ListActiveAsync(noteId, currentUser.UserId, now, ct)
            : [];

        var previousVersion = note.Version;

        var updated = note.UpdateContent(input.BaseVersion, input.Title, input.Content, now);
        if (updated.IsFailure)
        {
            return updated.Error.Code == NoteErrors.VersionConflict.Code
                ? updated.Error.WithDetails("serverNote", NoteMapper.ToServerNoteDto(note))
                : updated.Error;
        }

        // Phiên mở khoá hết hạn theo thời gian không thao tác: auto-save là thao tác, nên người đang soạn
        // không bị trả 423 giữa chừng chỉ vì đã sửa lâu hơn TTL.
        foreach (var session in unlockSessionsToExtend)
        {
            session.Extend(now);
        }

        await unitOfWork.SaveChangesAsync(ct);

        // Chỉ mục ngữ nghĩa không cần bước nào: EmbeddingIndexerJobService tự nhặt vì Version > indexedVersion.
        // Gửi lại đúng nội dung server đang có thì Version không đổi, nên không phát tín hiệu thừa.
        if (note.Version != previousVersion)
        {
            await realtime.NoteChangedAsync(note.Id, note.Version, currentUser.UserId, ct);
        }

        return NoteMapper.ToUpdateNoteContentOutputDto(note);
    }
}

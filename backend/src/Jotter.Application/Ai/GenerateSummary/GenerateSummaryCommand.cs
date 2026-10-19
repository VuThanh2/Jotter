using System.Runtime.CompilerServices;
using System.Text;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class GenerateSummaryCommand(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    INoteRepository notes,
    ILlmService llm,
    IUnitOfWork unitOfWork,
    TimeProvider clock)
{
    // Trả luồng sự kiện để client render dần; huỷ giữa chừng bằng ct gắn với request abort.
    // Luôn sinh mới và thay bản hiện tại — muốn xem bản cũ thì dùng GetSummaryQuery.
    public async Task<Result<IAsyncEnumerable<GenerateSummaryEventDto>>> ExecuteAsync(
        Guid noteId,
        CancellationToken ct)
    {
        // Kiểm quyền TRƯỚC khi gửi nội dung cho LLM: note đang khoá không bao giờ được đem đi tóm tắt.
        var access = await accessPolicy.GetAccessAsync(currentUser.UserId, noteId, ct);
        var permission = access.EnsureCanReadContent();
        if (permission.IsFailure)
        {
            return permission.Error;
        }

        var note = await notes.GetByIdAsync(noteId, ct);
        if (note is null)
        {
            return NoteErrors.NotFound;
        }

        var summarizable = note.EnsureSummarizable();
        if (summarizable.IsFailure)
        {
            return summarizable.Error;
        }

        var deltas = llm.SummarizeAsync(note.Title, note.Content, ct).GetAsyncEnumerator(ct);

        // Kéo trước chunk đầu tiên: provider lỗi ngay từ đầu vẫn trả được 503/429 đúng nghĩa
        // thay vì một response 200 mà stream hỏng.
        bool hasDelta;
        try
        {
            hasDelta = await deltas.MoveNextAsync();
        }
        catch (LlmException ex)
        {
            await deltas.DisposeAsync();
            return AiErrors.From(ex);
        }
        catch
        {
            await deltas.DisposeAsync();
            throw;
        }

        return Result.Success(StreamAsync(note, deltas, hasDelta, ct));
    }

    private async IAsyncEnumerable<GenerateSummaryEventDto> StreamAsync(
        Note note,
        IAsyncEnumerator<string> deltas,
        bool hasDelta,
        [EnumeratorCancellation] CancellationToken ct)
    {
        var summary = new StringBuilder();

        await using (deltas)
        {
            while (hasDelta)
            {
                summary.Append(deltas.Current);
                yield return new GenerateSummaryDeltaDto(deltas.Current);

                // Không yield được bên trong catch nên ghi lỗi lại rồi phát sự kiện ở ngoài.
                Error? failure = null;
                try
                {
                    hasDelta = await deltas.MoveNextAsync();
                }
                catch (LlmException ex)
                {
                    failure = AiErrors.From(ex);
                }

                if (failure is not null)
                {
                    yield return new GenerateSummaryFailedDto(failure.Code, failure.Message);
                    yield break;
                }
            }
        }

        // Chỉ lưu khi đã nhận trọn bản tóm tắt; bị huỷ giữa chừng thì bản cũ (nếu có) giữ nguyên.
        // Tóm tắt lưu tách biệt, không đụng Content, Version hay ChangeSeq của note.
        var saved = note.SetSummary(summary.ToString(), clock.GetUtcNow());
        if (saved.IsFailure)
        {
            yield return new GenerateSummaryFailedDto(saved.Error.Code, saved.Error.Message);
            yield break;
        }

        await unitOfWork.SaveChangesAsync(ct);

        yield return NoteMapper.ToGenerateSummaryCompletedDto(note.Summary!);
    }
}

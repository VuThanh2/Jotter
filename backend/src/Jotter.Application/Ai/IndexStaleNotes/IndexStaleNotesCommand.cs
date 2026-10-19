using Jotter.Domain;

namespace Jotter.Application;

// Do EmbeddingIndexerJobService gọi định kỳ, không có endpoint. Cơ chế kéo: note cần lập chỉ mục lại được phát hiện
// bằng Version > indexedVersion, nên thao tác lưu note không phải làm gì thêm và không bị chậm đi.
// Thành công trả về số note đã xử lý trong lô.
public sealed class IndexStaleNotesCommand(IEmbeddingStore embeddings, ILlmService llm, IUnitOfWork unitOfWork)
{
    public const int BatchSize = 20;

    // Note ngắn thì cả note là một chunk; note dài mới cần cắt để vừa giới hạn đầu vào của model embedding.
    private const int MaxChunkLength = 2_000;

    public async Task<Result<int>> ExecuteAsync(CancellationToken ct)
    {
        var staleNotes = await embeddings.ListStaleNotesAsync(BatchSize, ct);

        var processedCount = 0;
        Error? failure = null;

        foreach (var note in staleNotes)
        {
            try
            {
                await ReindexAsync(note, ct);
                processedCount++;
            }
            catch (LlmException ex)
            {
                // Provider lỗi thì các note sau cũng sẽ lỗi: dừng lô, vẫn giữ phần đã xong, lần chạy sau tự nhặt lại.
                failure = AiErrors.From(ex);
                break;
            }
        }

        await unitOfWork.SaveChangesAsync(ct);

        if (failure is not null)
        {
            return failure;
        }

        return processedCount;
    }

    // Note đang bảo vệ vẫn được lập chỉ mục; việc loại nó khỏi truy hồi diễn ra ở bước lọc quyền,
    // nhờ vậy mở khoá có hiệu lực ngay mà không phải chờ lập chỉ mục lại.
    private async Task ReindexAsync(StaleNote note, CancellationToken ct)
    {
        if (note.IsDeleted || (string.IsNullOrWhiteSpace(note.Title) && string.IsNullOrWhiteSpace(note.Content)))
        {
            await embeddings.RemoveAsync(note.NoteId, ct);
            return;
        }

        // Ghép tiêu đề vào từng chunk để chunk ở giữa note dài vẫn mang ngữ cảnh của note.
        var chunkTexts = SplitIntoChunks(note.Content)
            .DefaultIfEmpty(string.Empty)
            .Select(piece => JoinNonBlank(note.Title, piece))
            .ToList();

        var vectors = await llm.EmbedAsync(chunkTexts, ct);

        var chunks = chunkTexts
            .Select((text, index) => new EmbeddedChunk(index, text, vectors[index]))
            .ToList();

        await embeddings.ReplaceAsync(note.NoteId, note.Version, chunks, ct);
    }

    // Cắt tại dấu xuống dòng hoặc khoảng trắng gần nhất để không chẻ đôi một từ.
    private static List<string> SplitIntoChunks(string content)
    {
        var chunks = new List<string>();
        var remaining = content.AsSpan().Trim();

        while (remaining.Length > 0)
        {
            var length = Math.Min(MaxChunkLength, remaining.Length);
            if (length < remaining.Length)
            {
                var boundary = remaining[..length].LastIndexOfAny('\n', ' ');
                if (boundary > 0)
                {
                    length = boundary;
                }
            }

            chunks.Add(remaining[..length].Trim().ToString());
            remaining = remaining[length..].TrimStart();
        }

        return chunks;
    }

    private static string JoinNonBlank(string title, string piece) =>
        string.Join('\n', new[] { title, piece }.Where(part => !string.IsNullOrWhiteSpace(part)));
}

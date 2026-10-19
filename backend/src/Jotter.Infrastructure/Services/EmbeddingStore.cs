using Jotter.Application;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class EmbeddingStore(AppDbContext db, TimeProvider clock) : IEmbeddingStore
{
    // Cơ chế kéo: so Version với indexedVersion, không cần cờ "cần cập nhật" riêng.
    public async Task<IReadOnlyList<StaleNote>> ListStaleNotesAsync(int limit, CancellationToken ct) =>
        await db.Notes
            .Select(n => new
            {
                Note = n,
                IsBlank = n.Title.Trim() == string.Empty && n.Content.Trim() == string.Empty,
                IndexedVersion = db.NoteEmbeddings
                    .Where(e => e.NoteId == n.Id)
                    .Max(e => (long?)e.IndexedVersion)
            })
            .Where(x =>
                (x.Note.DeletedAt == null && !x.IsBlank
                    && (x.IndexedVersion == null || x.IndexedVersion < x.Note.Version))
                || ((x.Note.DeletedAt != null || x.IsBlank) && x.IndexedVersion != null))
            .OrderBy(x => x.Note.UpdatedAt)
            .Take(limit)
            .Select(x => new StaleNote(
                x.Note.Id,
                x.Note.Title,
                x.Note.Content,
                x.Note.Version,
                x.Note.DeletedAt != null))
            .ToListAsync(ct);

    // Cập nhật tại chỗ theo (NoteId, ChunkIndex): EF không cho track cùng lúc bản cũ đã xoá và bản mới trùng khoá.
    public async Task ReplaceAsync(
        Guid noteId,
        long indexedVersion,
        IReadOnlyList<EmbeddedChunk> chunks,
        CancellationToken ct)
    {
        var existing = await db.NoteEmbeddings.Where(e => e.NoteId == noteId).ToDictionaryAsync(e => e.ChunkIndex, ct);
        var now = clock.GetUtcNow();

        foreach (var chunk in chunks)
        {
            if (!existing.Remove(chunk.Index, out var embedding))
            {
                embedding = new NoteEmbedding { NoteId = noteId, ChunkIndex = chunk.Index };
                db.NoteEmbeddings.Add(embedding);
            }

            embedding.ChunkText = chunk.Text;
            embedding.Vector = chunk.Vector;
            embedding.IndexedVersion = indexedVersion;
            embedding.IndexedAt = now;
        }

        db.NoteEmbeddings.RemoveRange(existing.Values);
    }

    public async Task RemoveAsync(Guid noteId, CancellationToken ct)
    {
        var embeddings = await db.NoteEmbeddings.Where(e => e.NoteId == noteId).ToListAsync(ct);
        db.NoteEmbeddings.RemoveRange(embeddings);
    }

    // Chỉ chấm điểm trên tập noteIds đã lọc quyền. Brute-force cosine trong C# là đủ ở quy mô này, không cần pgvector.
    public async Task<IReadOnlyList<EmbeddingMatch>> SearchAsync(
        IReadOnlyCollection<Guid> noteIds,
        float[] queryVector,
        int topK,
        CancellationToken ct)
    {
        if (noteIds.Count == 0)
        {
            return [];
        }

        var ids = noteIds.ToList();
        var candidates = await db.NoteEmbeddings
            .Where(e => ids.Contains(e.NoteId))
            .Join(db.Notes, e => e.NoteId, n => n.Id, (e, n) => new { e.NoteId, n.Title, e.ChunkText, e.Vector })
            .ToListAsync(ct);

        return candidates
            .Select(c => new EmbeddingMatch(c.NoteId, c.Title, c.ChunkText, CosineSimilarity(queryVector, c.Vector)))
            .OrderByDescending(match => match.Score)
            .Take(topK)
            .ToList();
    }

    private static float CosineSimilarity(float[] a, float[] b)
    {
        // Vector lập chỉ mục bằng model khác chiều (đổi EmbeddingModel giữa chừng) thì coi như không liên quan.
        if (a.Length != b.Length || a.Length == 0)
        {
            return 0;
        }

        float dot = 0, normA = 0, normB = 0;
        for (var i = 0; i < a.Length; i++)
        {
            dot += a[i] * b[i];
            normA += a[i] * a[i];
            normB += b[i] * b[i];
        }

        var denominator = MathF.Sqrt(normA) * MathF.Sqrt(normB);
        return denominator == 0 ? 0 : dot / denominator;
    }
}

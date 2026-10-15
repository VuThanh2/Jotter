using Jotter.Domain;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class NoteRepository(AppDbContext db) : INoteRepository
{
    public Task<Note?> GetByIdAsync(Guid noteId, CancellationToken ct) =>
        Aggregates().FirstOrDefaultAsync(n => n.Id == noteId, ct);

    public Task<Note?> GetByAttachmentIdAsync(Guid attachmentId, CancellationToken ct) =>
        Aggregates().FirstOrDefaultAsync(n => n.Attachments.Any(a => a.Id == attachmentId), ct);

    public async Task<IReadOnlyList<Note>> ListByLabelAsync(Guid labelId, CancellationToken ct) =>
        await Aggregates().Where(n => n.Labels.Any(link => link.LabelId == labelId)).ToListAsync(ct);

    public Task<bool> ExistsAsync(Guid noteId, CancellationToken ct) =>
        db.Notes.AnyAsync(n => n.Id == noteId, ct);

    public void Add(Note note) => db.Notes.Add(note);

    // Split query: Include hai collection trong một câu SQL sẽ nhân chéo số dòng nhãn với số dòng tệp.
    private IQueryable<Note> Aggregates() =>
        db.Notes
            .Include(n => n.Labels)
            .Include(n => n.Attachments)
            .Include(n => n.Summary)
            .AsSplitQuery();
}

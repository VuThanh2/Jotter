using Jotter.Application;
using Jotter.Domain;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class NoteQueryService(AppDbContext db, NoteAccessPolicy accessPolicy) : INoteQueryService
{
    public const int PreviewLength = 200;

    public async Task<IReadOnlyList<ListNotesItemDto>> ListAsync(
        Guid userId,
        ListNotesFilter filter,
        ListNotesCursor? after,
        int take,
        CancellationToken ct)
    {
        var notes = filter.Scope switch
        {
            NoteListScope.Owned => accessPolicy.OwnedNotes(userId),
            NoteListScope.Shared => accessPolicy.SharedNotes(userId),
            _ => accessPolicy.VisibleNotes(userId)
        };

        notes = ApplyLabelFilter(notes, userId, filter.LabelIds);
        notes = ApplySearch(notes, userId, filter.SearchText);
        notes = ApplyCursor(notes, userId, after);

        // Ghim là trạng thái riêng của chủ sở hữu: note của người khác luôn xếp như note không ghim.
        var rows = await notes
            .OrderByDescending(n => n.OwnerId == userId && n.IsPinned)
            .ThenByDescending(n => n.OwnerId == userId ? n.PinnedAt : null)
            .ThenByDescending(n => n.UpdatedAt)
            .ThenByDescending(n => n.Id)
            .Take(take)
            .Select(n => new
            {
                n.Id,
                n.ConflictOfNoteId,
                n.Title,
                Preview = n.IsProtected ? string.Empty : n.Content.Substring(0, PreviewLength),
                IsOwner = n.OwnerId == userId,
                n.IsPinned,
                n.PinnedAt,
                n.IsProtected,
                IsShared = db.ShareGrants.Any(g => g.NoteId == n.Id && g.RevokedAt == null),
                LabelIds = n.Labels.Where(_ => n.OwnerId == userId).Select(link => link.LabelId).ToList(),
                n.Version,
                n.UpdatedAt
            })
            .AsSplitQuery()
            .ToListAsync(ct);

        return rows
            .Select(r => new ListNotesItemDto(
                r.Id,
                r.ConflictOfNoteId,
                r.Title,
                r.Preview,
                r.IsOwner ? r.IsPinned : null,
                r.IsOwner ? r.PinnedAt : null,
                r.IsProtected,
                r.IsShared,
                r.IsOwner ? r.LabelIds : null,
                r.Version,
                r.UpdatedAt))
            .ToList();
    }

    public async Task<GetNoteOutputDto?> GetAsync(Guid noteId, NoteAccess access, CancellationToken ct)
    {
        // Note đang khoá: nội dung và tệp đính kèm không được đọc khỏi DB, không chỉ bị ẩn khi trả về.
        var includeContent = !access.IsLocked;

        var row = await db.Notes
            .Where(n => n.Id == noteId && n.DeletedAt == null)
            .Select(n => new
            {
                n.Id,
                n.OwnerId,
                n.ConflictOfNoteId,
                n.Title,
                Content = includeContent ? n.Content : null,
                n.IsPinned,
                n.PinnedAt,
                n.IsProtected,
                LabelIds = n.Labels.Select(link => link.LabelId).ToList(),
                Attachments = n.Attachments
                    .Where(a => includeContent && a.DeletedAt == null)
                    .OrderBy(a => a.UploadedAt)
                    .Select(a => new AttachmentDto(a.Id, a.FileName, a.MimeType, a.SizeBytes, a.UploadedBy, a.UploadedAt))
                    .ToList(),
                SummaryAvailable = n.Summary != null,
                n.Version,
                n.ChangeSeq,
                n.CreatedAt,
                n.UpdatedAt
            })
            .AsSplitQuery()
            .FirstOrDefaultAsync(ct);

        if (row is null)
        {
            return null;
        }

        return new GetNoteOutputDto(
            row.Id,
            row.OwnerId,
            row.ConflictOfNoteId,
            row.Title,
            row.Content,
            access.IsOwner ? row.IsPinned : null,
            access.IsOwner ? row.PinnedAt : null,
            row.IsProtected,
            access.IsOwner ? row.LabelIds : null,
            row.Attachments,
            row.SummaryAvailable,
            row.Version,
            row.ChangeSeq,
            row.CreatedAt,
            row.UpdatedAt,
            access.Level);
    }

    public Task<long?> GetVersionAsync(Guid noteId, CancellationToken ct) =>
        db.Notes
            .Where(n => n.Id == noteId && n.DeletedAt == null)
            .Select(n => (long?)n.Version)
            .FirstOrDefaultAsync(ct);

    public async Task<IReadOnlyList<AttachmentDto>> ListAttachmentsAsync(Guid noteId, CancellationToken ct) =>
        await AliveAttachments()
            .Where(a => a.NoteId == noteId)
            .OrderBy(a => a.UploadedAt)
            .Select(a => new AttachmentDto(a.Id, a.FileName, a.MimeType, a.SizeBytes, a.UploadedBy, a.UploadedAt))
            .ToListAsync(ct);

    public Task<StoredAttachment?> FindAttachmentAsync(Guid attachmentId, CancellationToken ct) =>
        AliveAttachments()
            .Where(a => a.Id == attachmentId)
            .Select(a => new StoredAttachment(a.NoteId, a.FileName, a.MimeType, a.SizeBytes, a.StorageKey))
            .FirstOrDefaultAsync(ct);

    public Task<GetSummaryOutputDto?> GetSummaryAsync(Guid noteId, CancellationToken ct) =>
        db.Notes
            .Where(n => n.Id == noteId && n.DeletedAt == null && n.Summary != null)
            .Select(n => new GetSummaryOutputDto(n.Summary!.SummaryText, n.Summary.GeneratedAt))
            .FirstOrDefaultAsync(ct);

    private static IQueryable<Note> ApplyLabelFilter(
        IQueryable<Note> notes,
        Guid userId,
        IReadOnlyCollection<Guid> labelIds)
    {
        if (labelIds.Count == 0)
        {
            return notes;
        }

        // Nhãn là của riêng chủ sở hữu, nên bộ lọc nhãn chỉ khớp được note của chính người gọi. Nhiều nhãn = OR.
        var ids = labelIds.ToList();
        return notes.Where(n => n.OwnerId == userId && n.Labels.Any(link => ids.Contains(link.LabelId)));
    }

    private IQueryable<Note> ApplySearch(IQueryable<Note> notes, Guid userId, string searchText)
    {
        if (searchText.Length == 0)
        {
            return notes;
        }

        // Note đang bảo vệ chỉ được đối chiếu nội dung khi người gọi có phiên mở khoá còn hạn.
        var unlockSessions = accessPolicy.ActiveUnlockSessionsOf(userId);

        return notes.Where(n =>
            n.SearchTitle.Contains(searchText)
            || (n.SearchContent.Contains(searchText)
                && (!n.IsProtected || unlockSessions.Any(s => s.NoteId == n.Id))));
    }

    // Keyset theo đúng thứ tự sắp xếp (ghim, pinnedAt, updatedAt, id — đều giảm dần).
    private static IQueryable<Note> ApplyCursor(IQueryable<Note> notes, Guid userId, ListNotesCursor? after)
    {
        if (after is null)
        {
            return notes;
        }

        if (after.IsPinned)
        {
            return notes.Where(n =>
                !(n.OwnerId == userId && n.IsPinned)
                || n.PinnedAt < after.PinnedAt
                || (n.PinnedAt == after.PinnedAt
                    && (n.UpdatedAt < after.UpdatedAt
                        || (n.UpdatedAt == after.UpdatedAt && n.Id.CompareTo(after.NoteId) < 0))));
        }

        return notes.Where(n =>
            !(n.OwnerId == userId && n.IsPinned)
            && (n.UpdatedAt < after.UpdatedAt
                || (n.UpdatedAt == after.UpdatedAt && n.Id.CompareTo(after.NoteId) < 0)));
    }

    private IQueryable<Attachment> AliveAttachments() =>
        db.Attachments.Where(a => a.DeletedAt == null && db.Notes.Any(n => n.Id == a.NoteId && n.DeletedAt == null));
}

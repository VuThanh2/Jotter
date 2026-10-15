using System.Data;
using Jotter.Application;
using Jotter.Domain;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class SyncQueryService(AppDbContext db, NoteAccessPolicy accessPolicy) : ISyncQueryService
{
    public Task<long> GetPurgedChangeSeqAsync(CancellationToken ct) =>
        db.PurgeCheckpoints
            .Where(c => c.Id == PurgeCheckpoint.SingletonId)
            .Select(c => c.PurgedChangeSeq)
            .FirstOrDefaultAsync(ct);

    public async Task<PullChangesOutputDto> PullAsync(Guid userId, long since, int limit, CancellationToken ct)
    {
        // Một snapshot cho mọi truy vấn: transaction commit xen giữa không thể làm lệch điểm cắt trang.
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.RepeatableRead, ct);

        // Mỗi loại lấy dư một phần tử: loại nào còn bản ghi chưa lấy thì bản ghi đó chắc chắn nằm sau điểm cắt.
        var fetch = limit + 1;
        var grants = accessPolicy.ActiveGrantsFor(userId);
        var ownedNoteIds = db.Notes.Where(n => n.OwnerId == userId).Select(n => n.Id);

        // Tombstone vẫn nằm trong phạm vi: note đã xoá của chính mình, grant đã thu hồi của mình hoặc trên note của mình.
        var notes = await ProjectNotesAsync(
            db.Notes
                .Where(n => n.ChangeSeq > since && (n.OwnerId == userId || grants.Any(g => g.NoteId == n.Id)))
                .OrderBy(n => n.ChangeSeq)
                .Take(fetch),
            userId,
            ct);

        var labels = await db.Labels
            .Where(l => l.OwnerId == userId && l.ChangeSeq > since)
            .OrderBy(l => l.ChangeSeq)
            .Take(fetch)
            .Select(l => new SyncLabelDto(l.Id, l.Name, l.ChangeSeq, l.DeletedAt))
            .ToListAsync(ct);

        var shares = await db.ShareGrants
            .Where(g => g.ChangeSeq > since && (g.RecipientUserId == userId || ownedNoteIds.Contains(g.NoteId)))
            .OrderBy(g => g.ChangeSeq)
            .Take(fetch)
            .Select(g => new SyncShareDto(
                g.Id,
                g.NoteId,
                g.RecipientUserId,
                g.Permission,
                g.SharedAt,
                g.RevokedAt,
                g.ChangeSeq))
            .ToListAsync(ct);

        var attachments = await ProjectAttachments(
                db.Attachments
                    .Where(a => a.ChangeSeq > since
                        && (ownedNoteIds.Contains(a.NoteId) || grants.Any(g => g.NoteId == a.NoteId)))
                    .OrderBy(a => a.ChangeSeq)
                    .Take(fetch))
            .ToListAsync(ct);

        // Một sequence chung cho cả bốn bảng nên mỗi changeSeq là duy nhất: cắt theo một giá trị không bao giờ
        // chẻ đôi các bản ghi cùng mốc.
        var changeSeqs = notes.Select(n => n.ChangeSeq)
            .Concat(labels.Select(l => l.ChangeSeq))
            .Concat(shares.Select(s => s.ChangeSeq))
            .Concat(attachments.Select(a => a.ChangeSeq))
            .Order()
            .ToList();

        var hasMore = changeSeqs.Count > limit;
        var cutoff = changeSeqs.Count == 0 ? since : changeSeqs[Math.Min(limit, changeSeqs.Count) - 1];

        notes.RemoveAll(n => n.ChangeSeq > cutoff);
        labels.RemoveAll(l => l.ChangeSeq > cutoff);
        shares.RemoveAll(s => s.ChangeSeq > cutoff);
        attachments.RemoveAll(a => a.ChangeSeq > cutoff);

        await AddNewlySharedNotesAsync(userId, shares, notes, attachments, ct);

        await transaction.CommitAsync(ct);

        return new PullChangesOutputDto(
            notes,
            labels,
            shares,
            attachments,
            NextChangeSeq: cutoff,
            HasMore: hasMore,
            FullResyncRequired: false);
    }

    // Note vừa được chia sẻ (hoặc vừa đổi quyền) có thể mang changeSeq cũ hơn since. Nó đi kèm grant vừa nhận cùng
    // toàn bộ tệp đính kèm; phần đi kèm không dịch con trỏ nên không tính vào giới hạn trang.
    private async Task AddNewlySharedNotesAsync(
        Guid userId,
        IReadOnlyList<SyncShareDto> shares,
        List<SyncNoteDto> notes,
        List<SyncAttachmentDto> attachments,
        CancellationToken ct)
    {
        var includedNoteIds = notes.Select(n => n.NoteId).ToHashSet();
        var missingNoteIds = shares
            .Where(s => s.RecipientUserId == userId && s.RevokedAt is null && !includedNoteIds.Contains(s.NoteId))
            .Select(s => s.NoteId)
            .Distinct()
            .ToList();

        if (missingNoteIds.Count == 0)
        {
            return;
        }

        notes.AddRange(await ProjectNotesAsync(
            db.Notes.Where(n => missingNoteIds.Contains(n.Id) && n.DeletedAt == null),
            userId,
            ct));

        var includedAttachmentIds = attachments.Select(a => a.AttachmentId).ToHashSet();
        var sharedAttachments = await ProjectAttachments(
                db.Attachments.Where(a => missingNoteIds.Contains(a.NoteId) && a.DeletedAt == null))
            .ToListAsync(ct);

        attachments.AddRange(sharedAttachments.Where(a => !includedAttachmentIds.Contains(a.AttachmentId)));
    }

    // Note đang bảo vệ: content và searchContent luôn null vì không được nằm trong kho cục bộ.
    // Ghim và nhãn là của chủ sở hữu nên không trả cho người được chia sẻ.
    private async Task<List<SyncNoteDto>> ProjectNotesAsync(IQueryable<Note> notes, Guid userId, CancellationToken ct)
    {
        var grants = accessPolicy.ActiveGrantsFor(userId);

        var rows = await notes
            .Select(n => new
            {
                n.Id,
                n.OwnerId,
                n.ConflictOfNoteId,
                n.Title,
                Content = n.IsProtected ? null : n.Content,
                n.SearchTitle,
                SearchContent = n.IsProtected ? null : n.SearchContent,
                n.IsPinned,
                n.PinnedAt,
                n.IsProtected,
                LabelIds = n.Labels.Where(_ => n.OwnerId == userId).Select(link => link.LabelId).ToList(),
                SharedPermission = grants
                    .Where(g => g.NoteId == n.Id)
                    .Select(g => (SharePermission?)g.Permission)
                    .FirstOrDefault(),
                n.Version,
                n.ChangeSeq,
                n.CreatedAt,
                n.UpdatedAt,
                n.DeletedAt
            })
            .AsSplitQuery()
            .ToListAsync(ct);

        return rows
            .Select(r =>
            {
                var isOwner = r.OwnerId == userId;
                return new SyncNoteDto(
                    r.Id,
                    r.OwnerId,
                    r.ConflictOfNoteId,
                    r.Title,
                    r.Content,
                    r.SearchTitle,
                    r.SearchContent,
                    isOwner ? r.IsPinned : null,
                    isOwner ? r.PinnedAt : null,
                    r.IsProtected,
                    isOwner ? r.LabelIds : null,
                    ToAccessLevel(isOwner, r.SharedPermission),
                    r.Version,
                    r.ChangeSeq,
                    r.CreatedAt,
                    r.UpdatedAt,
                    r.DeletedAt);
            })
            .ToList();
    }

    private static IQueryable<SyncAttachmentDto> ProjectAttachments(IQueryable<Attachment> attachments) =>
        attachments.Select(a => new SyncAttachmentDto(
            a.Id,
            a.NoteId,
            a.FileName,
            a.MimeType,
            a.SizeBytes,
            a.UploadedBy,
            a.UploadedAt,
            a.DeletedAt,
            a.ChangeSeq));

    private static NoteAccessLevel ToAccessLevel(bool isOwner, SharePermission? sharedPermission) =>
        isOwner
            ? NoteAccessLevel.Owner
            : sharedPermission == SharePermission.Edit
                ? NoteAccessLevel.Edit
                : NoteAccessLevel.ReadOnly;
}

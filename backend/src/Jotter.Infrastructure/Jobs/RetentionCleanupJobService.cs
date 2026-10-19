using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Jotter.Infrastructure;

// UC-34: dọn tombstone quá hạn và các bản ghi "nhớ quá khứ" (OTP, ticket, phiên, ProcessedOperation) để không phình vô hạn.
public sealed class RetentionCleanupJobService(
    IServiceScopeFactory scopeFactory,
    IOptions<RetentionOptions> options,
    TimeProvider clock,
    ILogger<RetentionCleanupJobService> logger) : PeriodicJobService(logger)
{
    private readonly RetentionOptions _options = options.Value;

    protected override TimeSpan Interval => _options.CleanupInterval;

    protected override async Task RunOnceAsync(CancellationToken ct)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var now = clock.GetUtcNow();

        var tombstones = await PurgeTombstonesAsync(db, now, ct);
        var records = await PurgeExpiredRecordsAsync(db, now, ct);

        if (tombstones + records > 0)
        {
            logger.LogInformation(
                "Dọn dẹp định kỳ: xoá {Tombstones} tombstone và {Records} bản ghi hết hạn.",
                tombstones,
                records);
        }
    }

    // Ghi mốc changeSeq lớn nhất bị xoá trong cùng transaction với lần xoá: thiết bị đồng bộ từ mốc thấp hơn
    // có thể đã lỡ thao tác xoá, nên PullChanges sẽ buộc nó tải lại toàn bộ thay vì để dữ liệu đã xoá sống lại.
    private async Task<int> PurgeTombstonesAsync(AppDbContext db, DateTimeOffset now, CancellationToken ct)
    {
        var cutoff = now - _options.TombstoneRetention;
        await using var transaction = await db.Database.BeginTransactionAsync(ct);

        var purgedChangeSeq = new[]
        {
            await db.Notes.Where(n => n.DeletedAt < cutoff).MaxAsync(n => (long?)n.ChangeSeq, ct),
            await db.Labels.Where(l => l.DeletedAt < cutoff).MaxAsync(l => (long?)l.ChangeSeq, ct),
            await db.ShareGrants.Where(g => g.RevokedAt < cutoff).MaxAsync(g => (long?)g.ChangeSeq, ct),
            await db.Attachments.Where(a => a.DeletedAt < cutoff).MaxAsync(a => (long?)a.ChangeSeq, ct)
        }.Max();

        if (purgedChangeSeq is null)
        {
            return 0;
        }

        await AdvanceCheckpointAsync(db, purgedChangeSeq.Value, now, ct);

        // Xoá note cuối cùng: FK cascade dọn nốt liên kết nhãn, tóm tắt, embedding và phiên mở khoá của nó.
        var purged = await db.ShareGrants.Where(g => g.RevokedAt < cutoff).ExecuteDeleteAsync(ct)
            + await db.Attachments.Where(a => a.DeletedAt < cutoff).ExecuteDeleteAsync(ct)
            + await db.Labels.Where(l => l.DeletedAt < cutoff).ExecuteDeleteAsync(ct)
            + await db.Notes.Where(n => n.DeletedAt < cutoff).ExecuteDeleteAsync(ct);

        await transaction.CommitAsync(ct);

        return purged;
    }

    private async Task<int> PurgeExpiredRecordsAsync(AppDbContext db, DateTimeOffset now, CancellationToken ct)
    {
        var recordCutoff = now - _options.ExpiredRecordRetention;
        var operationCutoff = now - _options.ProcessedOperationRetention;

        return await db.ProcessedOperations.Where(o => o.ProcessedAt < operationCutoff).ExecuteDeleteAsync(ct)
            + await db.VerificationCodes.Where(c => c.ExpiresAt < recordCutoff).ExecuteDeleteAsync(ct)
            + await db.PasswordResetTickets.Where(t => t.ExpiresAt < recordCutoff).ExecuteDeleteAsync(ct)
            + await db.NoteUnlockSessions.Where(s => s.ExpiresAt < recordCutoff).ExecuteDeleteAsync(ct)
            + await db.UserSessions
                .Where(s => s.ExpiresAt < recordCutoff || s.RevokedAt < recordCutoff)
                .ExecuteDeleteAsync(ct);
    }

    private static async Task AdvanceCheckpointAsync(
        AppDbContext db,
        long purgedChangeSeq,
        DateTimeOffset now,
        CancellationToken ct)
    {
        var checkpoint = await db.PurgeCheckpoints.FirstOrDefaultAsync(c => c.Id == PurgeCheckpoint.SingletonId, ct);
        if (checkpoint is null)
        {
            checkpoint = new PurgeCheckpoint();
            db.PurgeCheckpoints.Add(checkpoint);
        }

        checkpoint.PurgedChangeSeq = Math.Max(checkpoint.PurgedChangeSeq, purgedChangeSeq);
        checkpoint.PurgedAt = now;

        await db.SaveChangesAsync(ct);
    }
}

using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Storage;

namespace Jotter.Infrastructure;

// Gán nextval('change_seq') cho mọi ISyncTracked được thêm hoặc sửa.
// Sequence cấp số trước khi commit, nên hai transaction có thể commit ngược thứ tự số đã nhận; khi đó client đã
// kéo tới số lớn hơn sẽ bỏ sót vĩnh viễn bản ghi mang số nhỏ hơn. Advisory lock giữ tới lúc commit buộc thứ tự commit
// trùng thứ tự changeSeq. Đăng ký Scoped vì giữ transaction tự mở của đúng một DbContext.
public sealed class ChangeSeqInterceptor : SaveChangesInterceptor
{
    private const long ChangeSeqLockKey = 0x4A6F74746572; // "Jotter"

    private IDbContextTransaction? _ownedTransaction;

    public override async ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData,
        InterceptionResult<int> result,
        CancellationToken cancellationToken = default)
    {
        if (eventData.Context is { } context)
        {
            await AssignChangeSeqAsync(context, cancellationToken);
        }

        return result;
    }

    public override async ValueTask<int> SavedChangesAsync(
        SaveChangesCompletedEventData eventData,
        int result,
        CancellationToken cancellationToken = default)
    {
        if (_ownedTransaction is null)
        {
            return result;
        }

        try
        {
            await _ownedTransaction.CommitAsync(cancellationToken);
        }
        finally
        {
            await ReleaseOwnedTransactionAsync();
        }

        return result;
    }

    public override Task SaveChangesFailedAsync(
        DbContextErrorEventData eventData,
        CancellationToken cancellationToken = default) =>
        ReleaseOwnedTransactionAsync();

    public override Task SaveChangesCanceledAsync(
        DbContextEventData eventData,
        CancellationToken cancellationToken = default) =>
        ReleaseOwnedTransactionAsync();

    // Mọi đường ghi trong hệ thống đều async; chặn bản đồng bộ để không ai vô tình lưu mà bỏ qua bước cấp changeSeq.
    public override InterceptionResult<int> SavingChanges(
        DbContextEventData eventData,
        InterceptionResult<int> result) =>
        throw new NotSupportedException("Chỉ hỗ trợ SaveChangesAsync.");

    private async Task AssignChangeSeqAsync(DbContext context, CancellationToken ct)
    {
        // Entries() tự chạy DetectChanges nên cũng thấy các entity vừa bị sửa mà chưa được phát hiện.
        var trackedEntries = context.ChangeTracker
            .Entries<ISyncTracked>()
            .Where(entry => entry.State is EntityState.Added or EntityState.Modified)
            .ToList();

        if (trackedEntries.Count == 0)
        {
            return;
        }

        if (context.Database.CurrentTransaction is null)
        {
            _ownedTransaction = await context.Database.BeginTransactionAsync(ct);
        }

        // Lỗi ở bước này xảy ra trước khi EF bắt đầu lưu nên SaveChangesFailed không được gọi: tự trả transaction.
        try
        {
            await context.Database.ExecuteSqlAsync($"SELECT pg_advisory_xact_lock({ChangeSeqLockKey})", ct);

            var values = await context.Database
                .SqlQueryRaw<long>(
                    $"SELECT nextval('{AppDbContext.ChangeSeqSequence}') AS \"Value\" FROM generate_series(1, {{0}})",
                    trackedEntries.Count)
                .ToListAsync(ct);

            for (var i = 0; i < trackedEntries.Count; i++)
            {
                trackedEntries[i].Property(nameof(ISyncTracked.ChangeSeq)).CurrentValue = values[i];
            }
        }
        catch
        {
            await ReleaseOwnedTransactionAsync();
            throw;
        }
    }

    private async Task ReleaseOwnedTransactionAsync()
    {
        if (_ownedTransaction is null)
        {
            return;
        }

        await _ownedTransaction.DisposeAsync();
        _ownedTransaction = null;
    }
}

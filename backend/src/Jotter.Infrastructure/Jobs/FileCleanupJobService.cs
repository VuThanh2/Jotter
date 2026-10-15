using Jotter.Application;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Jotter.Infrastructure;

// Mark-and-sweep: xoá mọi tệp không còn được bản ghi sống nào tham chiếu. Một cơ chế bao được cả attachment đã
// tombstone, avatar cũ bị thay hoặc gỡ, lẫn bytes mồ côi khi commit metadata thất bại — tách khỏi transaction nghiệp vụ.
public sealed class FileCleanupJobService(
    IServiceScopeFactory scopeFactory,
    IFileInventory inventory,
    IFileStorage storage,
    IOptions<StorageOptions> options,
    TimeProvider clock,
    ILogger<FileCleanupJobService> logger) : PeriodicJobService(logger)
{
    private const int BatchSize = 500;

    private readonly StorageOptions _options = options.Value;

    protected override TimeSpan Interval => _options.CleanupInterval;

    protected override async Task RunOnceAsync(CancellationToken ct)
    {
        // Bytes được ghi trước khi metadata commit; tệp còn mới có thể thuộc một request đang chạy dở.
        var cutoff = clock.GetUtcNow() - _options.OrphanGracePeriod;
        var deletedCount = 0;

        var batch = new List<string>(BatchSize);
        await foreach (var key in inventory.ListKeysModifiedBeforeAsync(cutoff, ct))
        {
            batch.Add(key);
            if (batch.Count == BatchSize)
            {
                deletedCount += await DeleteUnreferencedAsync(batch, ct);
                batch.Clear();
            }
        }

        deletedCount += await DeleteUnreferencedAsync(batch, ct);

        if (deletedCount > 0)
        {
            logger.LogInformation("Đã dọn {Count} tệp không còn được tham chiếu.", deletedCount);
        }
    }

    private async Task<int> DeleteUnreferencedAsync(List<string> keys, CancellationToken ct)
    {
        if (keys.Count == 0)
        {
            return 0;
        }

        await using var scope = scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var referenced = await db.Attachments
            .Where(a => a.DeletedAt == null && keys.Contains(a.StorageKey))
            .Select(a => a.StorageKey)
            .Concat(db.Users
                .Where(u => u.AvatarStorageKey != null && keys.Contains(u.AvatarStorageKey))
                .Select(u => u.AvatarStorageKey!))
            .ToListAsync(ct);

        var unreferenced = keys.Except(referenced).ToList();
        foreach (var key in unreferenced)
        {
            await storage.DeleteAsync(key, ct);
        }

        return unreferenced.Count;
    }
}

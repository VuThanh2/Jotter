using Jotter.Application;
using Microsoft.EntityFrameworkCore.Storage;

namespace Jotter.Infrastructure;

// Bao quanh action: lần ghi nghiệp vụ và bản ghi ProcessedOperation commit cùng lúc hoặc cùng rollback.
// Tín hiệu realtime phát trong lúc action chạy chỉ được gửi sau khi commit, để không báo cho dữ liệu chưa tồn tại.
public sealed class IdempotencyScope(
    AppDbContext db,
    IDbContextTransaction transaction,
    PendingRealtimeSignals pendingSignals,
    TimeProvider clock,
    Guid userId,
    Guid operationId) : IIdempotencyScope
{
    private bool _completed;

    public async Task CompleteAsync(IdempotentResponse response, CancellationToken ct)
    {
        if (_completed)
        {
            throw new InvalidOperationException("IdempotencyScope đã được Complete.");
        }

        db.ProcessedOperations.Add(new ProcessedOperation
        {
            UserId = userId,
            OperationId = operationId,
            StatusCode = response.StatusCode,
            ContentType = response.ContentType,
            ResponseBody = response.Body,
            ProcessedAt = clock.GetUtcNow()
        });

        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        _completed = true;

        await pendingSignals.FlushAsync();
    }

    public async ValueTask DisposeAsync()
    {
        if (!_completed)
        {
            pendingSignals.Discard();
        }

        // Dispose một transaction chưa commit là rollback.
        await transaction.DisposeAsync();
    }
}

using Jotter.Application;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class IdempotencyStore(AppDbContext db, PendingRealtimeSignals pendingSignals, TimeProvider clock)
    : IIdempotencyStore
{
    public Task<IdempotentResponse?> FindAsync(Guid userId, Guid operationId, CancellationToken ct) =>
        db.ProcessedOperations
            .Where(o => o.UserId == userId && o.OperationId == operationId)
            .Select(o => new IdempotentResponse(o.StatusCode, o.ContentType, o.ResponseBody))
            .FirstOrDefaultAsync(ct);

    // Hai request trùng opId chạy đồng thời: request đến sau vấp khoá chính của processed_operations lúc Complete,
    // transaction của nó rollback toàn bộ và lần thử lại kế tiếp sẽ nhận đúng response đã lưu.
    public async Task<IIdempotencyScope> BeginAsync(Guid userId, Guid operationId, CancellationToken ct)
    {
        var transaction = await db.Database.BeginTransactionAsync(ct);
        return new IdempotencyScope(db, transaction, pendingSignals, clock, userId, operationId);
    }
}

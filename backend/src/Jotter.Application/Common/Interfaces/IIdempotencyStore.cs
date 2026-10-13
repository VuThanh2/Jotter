namespace Jotter.Application;

// Dùng bởi IdempotencyFilter ở Api: lần ghi nghiệp vụ và bản ghi ProcessedOperation commit trong cùng một transaction.
public interface IIdempotencyStore
{
    Task<IdempotentResponse?> FindAsync(Guid userId, Guid operationId, CancellationToken ct);

    Task<IIdempotencyScope> BeginAsync(Guid userId, Guid operationId, CancellationToken ct);
}

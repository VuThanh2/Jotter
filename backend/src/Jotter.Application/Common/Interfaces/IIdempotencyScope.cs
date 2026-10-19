namespace Jotter.Application;

// Dispose khi chưa Complete thì rollback toàn bộ, kể cả lần ghi nghiệp vụ của action.
public interface IIdempotencyScope : IAsyncDisposable
{
    Task CompleteAsync(IdempotentResponse response, CancellationToken ct);
}

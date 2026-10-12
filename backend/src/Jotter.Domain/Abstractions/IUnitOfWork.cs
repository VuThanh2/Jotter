namespace Jotter.Domain;

public interface IUnitOfWork
{
    Task SaveChangesAsync(CancellationToken ct);
}

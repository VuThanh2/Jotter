namespace Jotter.Application;

public interface IFileStorage
{
    Task SaveAsync(string storageKey, Stream content, CancellationToken ct);

    Task<Stream> OpenReadAsync(string storageKey, CancellationToken ct);

    Task DeleteAsync(string storageKey, CancellationToken ct);
}

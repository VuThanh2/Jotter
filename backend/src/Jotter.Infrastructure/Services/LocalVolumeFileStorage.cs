using System.Runtime.CompilerServices;
using Jotter.Application;
using Microsoft.Extensions.Options;

namespace Jotter.Infrastructure;

// Railway Volume (hoặc volume của docker compose). Không bao giờ ghi vào wwwroot: filesystem container là ephemeral.
public sealed class LocalVolumeFileStorage : IFileStorage, IFileInventory
{
    private const string TemporaryExtension = ".tmp";
    private const int CopyBufferSize = 81_920;

    private readonly string _rootPath;

    public LocalVolumeFileStorage(IOptions<StorageOptions> options)
    {
        _rootPath = Path.GetFullPath(options.Value.RootPath);
        Directory.CreateDirectory(_rootPath);
    }

    // Ghi ra tệp tạm rồi đổi tên: tệp đích hoặc đầy đủ hoặc không tồn tại, không bao giờ bị đọc khi đang ghi dở.
    public async Task SaveAsync(string storageKey, Stream content, CancellationToken ct)
    {
        var path = ResolvePath(storageKey);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);

        var temporaryPath = path + TemporaryExtension;
        try
        {
            await using (var file = new FileStream(
                temporaryPath,
                FileMode.Create,
                FileAccess.Write,
                FileShare.None,
                CopyBufferSize,
                FileOptions.Asynchronous))
            {
                await content.CopyToAsync(file, CopyBufferSize, ct);
            }

            File.Move(temporaryPath, path, overwrite: true);
        }
        catch
        {
            File.Delete(temporaryPath);
            throw;
        }
    }

    public Task<Stream> OpenReadAsync(string storageKey, CancellationToken ct)
    {
        Stream stream = new FileStream(
            ResolvePath(storageKey),
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            CopyBufferSize,
            FileOptions.Asynchronous | FileOptions.SequentialScan);

        return Task.FromResult(stream);
    }

    public Task DeleteAsync(string storageKey, CancellationToken ct)
    {
        File.Delete(ResolvePath(storageKey));
        return Task.CompletedTask;
    }

    public async IAsyncEnumerable<string> ListKeysModifiedBeforeAsync(
        DateTimeOffset cutoff,
        [EnumeratorCancellation] CancellationToken ct)
    {
        await Task.Yield();

        foreach (var path in Directory.EnumerateFiles(_rootPath, "*", SearchOption.AllDirectories))
        {
            ct.ThrowIfCancellationRequested();

            var key = Path.GetRelativePath(_rootPath, path).Replace(Path.DirectorySeparatorChar, '/');
            if (StorageKeys.IsValid(key) && File.GetLastWriteTimeUtc(path) < cutoff.UtcDateTime)
            {
                yield return key;
            }
        }
    }

    // Key không hợp lệ là lỗi lập trình: key luôn do server sinh, nên từ chối thay vì cố "làm sạch".
    private string ResolvePath(string storageKey)
    {
        if (!StorageKeys.IsValid(storageKey))
        {
            throw new ArgumentException($"storageKey không hợp lệ: '{storageKey}'.", nameof(storageKey));
        }

        var path = Path.GetFullPath(Path.Combine(_rootPath, storageKey));
        if (!path.StartsWith(_rootPath + Path.DirectorySeparatorChar, StringComparison.Ordinal))
        {
            throw new ArgumentException("storageKey trỏ ra ngoài thư mục lưu trữ.", nameof(storageKey));
        }

        return path;
    }
}

namespace Jotter.Domain;

public sealed class Attachment : Entity, ISyncTracked
{
    public const int MaxFileNameLength = 255;
    public const long MaxSizeBytes = 25L * 1024 * 1024;

    private Attachment()
    {
    }

    private Attachment(
        Guid noteId,
        string fileName,
        string mimeType,
        long sizeBytes,
        string storageKey,
        Guid uploadedBy,
        DateTimeOffset now) : base(Guid.CreateVersion7(now))
    {
        NoteId = noteId;
        FileName = fileName;
        MimeType = mimeType;
        SizeBytes = sizeBytes;
        StorageKey = storageKey;
        UploadedBy = uploadedBy;
        UploadedAt = now;
    }

    public Guid NoteId { get; private init; }

    public string FileName { get; private init; } = string.Empty;

    public string MimeType { get; private init; } = string.Empty;

    public long SizeBytes { get; private init; }

    public string StorageKey { get; private init; } = string.Empty;

    public Guid UploadedBy { get; private init; }

    public DateTimeOffset UploadedAt { get; private init; }

    public DateTimeOffset? DeletedAt { get; private set; }

    public long ChangeSeq { get; private set; }

    public bool IsDeleted => DeletedAt is not null;

    // mimeType lấy từ magic bytes và storageKey do server sinh, nên thiếu chúng là lỗi lập trình chứ không phải lỗi nghiệp vụ.
    internal static Result<Attachment> Create(
        Guid noteId,
        string? fileName,
        string mimeType,
        long sizeBytes,
        string storageKey,
        Guid uploadedBy,
        DateTimeOffset now)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(mimeType);
        ArgumentException.ThrowIfNullOrWhiteSpace(storageKey);

        var name = ExtractFileName(fileName);
        if (name.Length == 0 || name.Length > MaxFileNameLength)
        {
            return FileErrors.InvalidFileName;
        }

        if (sizeBytes <= 0)
        {
            return FileErrors.EmptyFile;
        }

        if (sizeBytes > MaxSizeBytes)
        {
            return FileErrors.FileTooLarge;
        }

        return new Attachment(noteId, name, mimeType, sizeBytes, storageKey, uploadedBy, now);
    }

    internal void MarkDeleted(DateTimeOffset now) => DeletedAt ??= now;

    // Một số trình duyệt gửi kèm đường dẫn (vd. C:\fakepath\a.png) — chỉ giữ phần tên tệp.
    private static string ExtractFileName(string? fileName)
    {
        if (string.IsNullOrWhiteSpace(fileName))
        {
            return string.Empty;
        }

        var lastSeparator = fileName.LastIndexOfAny(['/', '\\']);
        return fileName[(lastSeparator + 1)..].Trim();
    }
}

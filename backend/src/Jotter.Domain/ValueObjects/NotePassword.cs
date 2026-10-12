namespace Jotter.Domain;

// Chỉ dựng được từ hash. MinLength/MaxLength áp cho mật khẩu thô ở validator — Domain không bao giờ thấy bản thô.
public sealed record NotePassword
{
    public const int MinLength = 4;
    public const int MaxLength = 128;

    private NotePassword(string hash) => Hash = hash;

    public string Hash { get; }

    public static NotePassword FromHash(string hash)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(hash);
        return new NotePassword(hash);
    }

    public override string ToString() => "***";
}

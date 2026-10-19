namespace Jotter.Domain;

public sealed record NoteTitle
{
    public const int MaxLength = 200;

    private NoteTitle(string value) => Value = value;

    public string Value { get; }

    public bool IsBlank => string.IsNullOrWhiteSpace(Value);

    // Không Trim và cho phép rỗng: auto-save gửi đúng thứ đang gõ, người dùng có thể gõ nội dung trước tiêu đề.
    public static Result<NoteTitle> Create(string? value)
    {
        var title = value ?? string.Empty;

        if (title.Length > MaxLength)
        {
            return NoteErrors.TitleTooLong;
        }

        return new NoteTitle(title);
    }

    public override string ToString() => Value;
}

namespace Jotter.Domain;

public sealed record NoteContent
{
    public const int MaxLength = 50_000;

    private NoteContent(string value) => Value = value;

    public string Value { get; }

    public bool IsBlank => string.IsNullOrWhiteSpace(Value);

    public static Result<NoteContent> Create(string? value)
    {
        var content = value ?? string.Empty;

        if (content.Length > MaxLength)
        {
            return NoteErrors.ContentTooLong;
        }

        return new NoteContent(content);
    }

    public override string ToString() => Value;
}

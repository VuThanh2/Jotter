namespace Jotter.Domain;

public sealed record LabelName
{
    public const int MaxLength = 50;

    private LabelName(string value) => Value = value;

    public string Value { get; }

    public static Result<LabelName> Create(string? value)
    {
        var name = value?.Trim() ?? string.Empty;

        if (name.Length == 0)
        {
            return LabelErrors.NameRequired;
        }

        if (name.Length > MaxLength)
        {
            return LabelErrors.NameTooLong;
        }

        return new LabelName(name);
    }

    public override string ToString() => Value;
}

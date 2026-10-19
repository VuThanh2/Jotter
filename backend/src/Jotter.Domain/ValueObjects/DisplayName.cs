namespace Jotter.Domain;

public sealed record DisplayName
{
    public const int MaxLength = 100;

    private DisplayName(string value) => Value = value;

    public string Value { get; }

    public static Result<DisplayName> Create(string? value)
    {
        var name = value?.Trim() ?? string.Empty;

        if (name.Length == 0)
        {
            return UserErrors.DisplayNameRequired;
        }

        if (name.Length > MaxLength)
        {
            return UserErrors.DisplayNameTooLong;
        }

        return new DisplayName(name);
    }

    public override string ToString() => Value;
}

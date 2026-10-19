namespace Jotter.Domain;

public sealed record Error(string Code, string Message, ErrorType Type)
{
    public IReadOnlyDictionary<string, object?>? Details { get; init; }

    public Error WithDetails(string key, object? value)
    {
        var details = Details is null
            ? new Dictionary<string, object?>()
            : new Dictionary<string, object?>(Details);

        details[key] = value;
        return this with { Details = details };
    }

    public static Error Validation(string code, string message) => new(code, message, ErrorType.Validation);

    public static Error Unauthorized(string code, string message) => new(code, message, ErrorType.Unauthorized);

    public static Error Forbidden(string code, string message) => new(code, message, ErrorType.Forbidden);

    public static Error NotFound(string code, string message) => new(code, message, ErrorType.NotFound);

    public static Error Conflict(string code, string message) => new(code, message, ErrorType.Conflict);

    public static Error Locked(string code, string message) => new(code, message, ErrorType.Locked);

    public static Error TooManyRequests(string code, string message) => new(code, message, ErrorType.TooManyRequests);

    public static Error Unavailable(string code, string message) => new(code, message, ErrorType.Unavailable);
}

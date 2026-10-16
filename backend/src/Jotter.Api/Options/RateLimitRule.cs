namespace Jotter.Api;

public sealed class RateLimitRule
{
    public int PermitLimit { get; init; }

    public TimeSpan Window { get; init; }

    public bool IsValid => PermitLimit > 0 && Window > TimeSpan.Zero;
}

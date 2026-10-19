namespace Jotter.Application;

public sealed record IssueRealtimeTokenOutputDto(string Token, DateTimeOffset ExpiresAt);

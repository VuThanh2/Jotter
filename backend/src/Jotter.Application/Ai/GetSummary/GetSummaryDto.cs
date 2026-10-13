namespace Jotter.Application;

public sealed record GetSummaryOutputDto(string SummaryText, DateTimeOffset GeneratedAt);

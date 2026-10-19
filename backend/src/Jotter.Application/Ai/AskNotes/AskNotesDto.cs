namespace Jotter.Application;

public sealed record AskNotesInputDto(string Question);

public sealed record AskNotesOutputDto(string Answer, bool HasEnoughContext, IReadOnlyList<CitationDto> Citations);

public sealed record CitationDto(Guid NoteId, string Title, string Excerpt, float Score);

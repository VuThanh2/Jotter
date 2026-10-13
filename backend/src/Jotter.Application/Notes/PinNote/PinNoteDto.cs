namespace Jotter.Application;

public sealed record PinNoteInputDto(bool IsPinned);

public sealed record PinNoteOutputDto(Guid NoteId, bool IsPinned, DateTimeOffset? PinnedAt, long ChangeSeq);

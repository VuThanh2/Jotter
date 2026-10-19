namespace Jotter.Application;

public sealed record EnableProtectionInputDto(string Password, string ConfirmPassword);

public sealed record EnableProtectionOutputDto(Guid NoteId, bool IsProtected, long ChangeSeq);

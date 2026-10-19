namespace Jotter.Application;

public sealed record RenameLabelInputDto(string Name);

public sealed record RenameLabelOutputDto(Guid LabelId, string Name, long ChangeSeq);

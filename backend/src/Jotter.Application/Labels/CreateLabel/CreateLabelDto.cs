namespace Jotter.Application;

public sealed record CreateLabelInputDto(Guid LabelId, string Name);

public sealed record CreateLabelOutputDto(Guid LabelId, string Name, long ChangeSeq);

using Jotter.Domain;

namespace Jotter.Application;

public static class LabelMapper
{
    public static CreateLabelOutputDto ToCreateLabelOutputDto(Label label) =>
        new(label.Id, label.Name, label.ChangeSeq);

    public static RenameLabelOutputDto ToRenameLabelOutputDto(Label label) =>
        new(label.Id, label.Name, label.ChangeSeq);
}

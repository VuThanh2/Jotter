namespace Jotter.Domain;

public sealed class NoteLabelLink
{
    private NoteLabelLink()
    {
    }

    internal NoteLabelLink(Guid noteId, Guid labelId)
    {
        NoteId = noteId;
        LabelId = labelId;
    }

    public Guid NoteId { get; private init; }

    public Guid LabelId { get; private init; }
}

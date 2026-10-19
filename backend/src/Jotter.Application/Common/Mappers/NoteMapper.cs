using Jotter.Domain;

namespace Jotter.Application;

public static class NoteMapper
{
    public static CreateNoteOutputDto ToCreateNoteOutputDto(Note note) =>
        new(
            note.Id,
            note.ConflictOfNoteId,
            note.Title,
            note.Content,
            note.Version,
            note.ChangeSeq,
            note.CreatedAt,
            note.UpdatedAt);

    public static UpdateNoteContentOutputDto ToUpdateNoteContentOutputDto(Note note) =>
        new(note.Id, note.Version, note.ChangeSeq, note.UpdatedAt);

    public static ServerNoteDto ToServerNoteDto(Note note) =>
        new(note.Id, note.Title, note.Content, note.Version, note.ChangeSeq, note.UpdatedAt);

    public static PinNoteOutputDto ToPinNoteOutputDto(Note note) =>
        new(note.Id, note.IsPinned, note.PinnedAt, note.ChangeSeq);

    public static SetNoteLabelsOutputDto ToSetNoteLabelsOutputDto(Note note) =>
        new(note.Id, note.Labels.Select(link => link.LabelId).ToList(), note.ChangeSeq);

    public static EnableProtectionOutputDto ToEnableProtectionOutputDto(Note note) =>
        new(note.Id, note.IsProtected, note.ChangeSeq);

    public static UploadedAttachmentDto ToUploadedAttachmentDto(Attachment attachment) =>
        new(
            attachment.Id,
            attachment.FileName,
            attachment.MimeType,
            attachment.SizeBytes,
            attachment.UploadedAt,
            attachment.ChangeSeq);

    public static GenerateSummaryCompletedDto ToGenerateSummaryCompletedDto(NoteSummary summary) =>
        new(summary.SummaryText, summary.GeneratedAt);
}

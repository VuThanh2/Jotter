namespace Jotter.Application;

// Luôn gửi trọn bộ nhãn thay vì patch từng liên kết, nên liên kết Note↔Label không cần changeSeq hay tombstone riêng.
public sealed record SetNoteLabelsInputDto(IReadOnlyList<Guid> LabelIds);

public sealed record SetNoteLabelsOutputDto(Guid NoteId, IReadOnlyList<Guid> LabelIds, long ChangeSeq);

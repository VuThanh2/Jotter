namespace Jotter.Application;

public sealed record ListLabelsOutputDto(IReadOnlyList<ListLabelsItemDto> Items);

// NoteCount chỉ đếm note chưa xoá, phục vụ hộp thoại xác nhận khi xoá nhãn.
public sealed record ListLabelsItemDto(Guid LabelId, string Name, int NoteCount, long ChangeSeq);

namespace Jotter.Application;

// Thứ tự tăng dần để NoteAccess so sánh "đủ mức quyền" bằng toán tử <.
public enum NoteAccessLevel
{
    None,
    ReadOnly,
    Edit,
    Owner
}

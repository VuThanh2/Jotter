namespace Jotter.Infrastructure;

// NoteId có khi lỗi gắn với một lần join cụ thể, để client biết note nào bị từ chối.
public sealed record ErrorMessage(string Reason, Guid? NoteId = null) : RealtimeMessage("error")
{
    public const string Forbidden = "forbidden";
    public const string Invalid = "invalid";
    public const string Unauthorized = "unauthorized";
}

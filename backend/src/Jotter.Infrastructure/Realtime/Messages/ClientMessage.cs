namespace Jotter.Infrastructure;

// Client chỉ gửi join / leave / ping; kênh không nhận thao tác ghi nào.
public sealed record ClientMessage(string? Type, Guid? NoteId)
{
    public const string Join = "join";
    public const string Leave = "leave";
    public const string Ping = "ping";
}

namespace Jotter.Domain;

public sealed class NoteSummary
{
    private NoteSummary()
    {
    }

    private NoteSummary(Guid noteId, string summaryText, DateTimeOffset generatedAt)
    {
        NoteId = noteId;
        SummaryText = summaryText;
        GeneratedAt = generatedAt;
    }

    public Guid NoteId { get; private init; }

    public string SummaryText { get; private set; } = string.Empty;

    public DateTimeOffset GeneratedAt { get; private set; }

    internal static NoteSummary Create(Guid noteId, string summaryText, DateTimeOffset now) =>
        new(noteId, summaryText, now);

    // Cập nhật tại chỗ thay vì tạo bản mới: cùng khoá NoteId nên EF không cho track hai instance.
    internal void Replace(string summaryText, DateTimeOffset now)
    {
        SummaryText = summaryText;
        GeneratedAt = now;
    }
}

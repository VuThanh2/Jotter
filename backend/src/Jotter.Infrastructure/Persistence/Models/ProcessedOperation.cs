namespace Jotter.Infrastructure;

// Sổ chống thực thi trùng: gặp lại (UserId, OperationId) thì trả nguyên response đã lưu.
public sealed class ProcessedOperation
{
    public Guid UserId { get; set; }

    public Guid OperationId { get; set; }

    public int StatusCode { get; set; }

    public string? ContentType { get; set; }

    public byte[] ResponseBody { get; set; } = [];

    public DateTimeOffset ProcessedAt { get; set; }
}

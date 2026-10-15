namespace Jotter.Infrastructure;

public sealed class RetentionOptions
{
    public const string SectionName = "Retention";

    // Thiết bị ngoại tuyến lâu hơn mốc này phải tải lại toàn bộ (fullResyncRequired).
    public TimeSpan TombstoneRetention { get; init; } = TimeSpan.FromDays(30);

    public TimeSpan ProcessedOperationRetention { get; init; } = TimeSpan.FromDays(14);

    // Áp cho OTP, reset ticket, phiên đăng nhập và phiên mở khoá, tính từ lúc hết hạn hoặc bị thu hồi.
    public TimeSpan ExpiredRecordRetention { get; init; } = TimeSpan.FromDays(7);

    public TimeSpan CleanupInterval { get; init; } = TimeSpan.FromHours(1);
}

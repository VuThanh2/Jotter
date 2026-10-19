namespace Jotter.Application;

// Các sự kiện của luồng text/event-stream; Api chọn tên event SSE theo kiểu cụ thể.
public abstract record GenerateSummaryEventDto;

public sealed record GenerateSummaryDeltaDto(string Delta) : GenerateSummaryEventDto;

public sealed record GenerateSummaryCompletedDto(string SummaryText, DateTimeOffset GeneratedAt) : GenerateSummaryEventDto;

// Lỗi xảy ra khi đã bắt đầu stream thì không còn đổi được mã HTTP, nên báo bằng một sự kiện riêng.
public sealed record GenerateSummaryFailedDto(string Code, string Message) : GenerateSummaryEventDto;

using Jotter.Domain;

namespace Jotter.Application;

public static class AiErrors
{
    public static readonly Error LlmUnavailable =
        Error.Unavailable("LlmUnavailable", "Dịch vụ AI đang lỗi hoặc quá tải. Vui lòng thử lại sau.");

    public static readonly Error LlmQuotaExceeded =
        Error.TooManyRequests("LlmQuotaExceeded", "Dịch vụ AI đã hết hạn mức. Vui lòng thử lại sau.");

    public static Error From(LlmException exception) => exception.Kind switch
    {
        LlmFailureKind.QuotaExceeded => LlmQuotaExceeded,
        _ => LlmUnavailable
    };
}

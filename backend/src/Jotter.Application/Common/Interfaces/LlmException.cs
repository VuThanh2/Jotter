namespace Jotter.Application;

// Provider lỗi là tình huống vận hành đã lường trước: Application bắt lại và đổi thành 503/429 thay vì để thành 500.
public sealed class LlmException(LlmFailureKind kind, string message, Exception? innerException = null)
    : Exception(message, innerException)
{
    public LlmFailureKind Kind { get; } = kind;
}

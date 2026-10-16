using Jotter.Domain;

namespace Jotter.Api;

public static class RateLimitPolicies
{
    public const string Auth = "auth";
    public const string OtpSend = "otp-send";
    public const string OtpVerify = "otp-verify";
    public const string NoteUnlock = "note-unlock";
    public const string Llm = "llm";

    // Mã lỗi khớp trang API Endpoint: chặn nhập sai (mã OTP, mật khẩu note) là TooManyAttempts — use case giao hẳn
    // việc đếm lần thử cho rate limiter — còn lại là TooManyRequests.
    public static Error RejectionErrorOf(string? policy) => policy switch
    {
        OtpVerify => OtpErrors.TooManyAttempts,
        NoteUnlock => ProtectionErrors.TooManyAttempts,
        _ => ApiErrors.TooManyRequests
    };
}

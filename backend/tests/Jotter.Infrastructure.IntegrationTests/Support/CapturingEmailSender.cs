using Jotter.Application;
using Jotter.Domain;

namespace Jotter.Infrastructure.IntegrationTests;

// Giữ lại mã OTP đã "gửi" để test đi tiếp luồng kích hoạt và đặt lại mật khẩu như người dùng thật.
internal sealed class CapturingEmailSender : IEmailSender
{
    private readonly Lock _gate = new();
    private readonly Dictionary<string, string> _lastCodeByEmail = new(StringComparer.OrdinalIgnoreCase);

    public string LastCodeSentTo(string email)
    {
        lock (_gate)
        {
            return _lastCodeByEmail[email];
        }
    }

    public Task SendActivationCodeAsync(string email, string displayName, string code, CancellationToken ct) =>
        Capture(email, code);

    public Task SendPasswordResetCodeAsync(string email, string displayName, string code, CancellationToken ct) =>
        Capture(email, code);

    public Task SendNoteSharedAsync(
        string email,
        string recipientName,
        string sharedByName,
        string noteTitle,
        SharePermission permission,
        CancellationToken ct) =>
        Task.CompletedTask;

    private Task Capture(string email, string code)
    {
        lock (_gate)
        {
            _lastCodeByEmail[email] = code;
        }

        return Task.CompletedTask;
    }
}

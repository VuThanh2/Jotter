namespace Jotter.Domain;

public interface IVerificationCodeRepository
{
    // Mã chưa tiêu thụ và chưa bị vô hiệu — có thể đã hết hạn.
    Task<VerificationCode?> GetPendingAsync(Guid userId, OtpPurpose purpose, CancellationToken ct);

    // Mã cấp gần nhất bất kể trạng thái, dùng để tính thời gian chờ gửi lại.
    Task<VerificationCode?> GetLatestAsync(Guid userId, OtpPurpose purpose, CancellationToken ct);

    void Add(VerificationCode code);
}

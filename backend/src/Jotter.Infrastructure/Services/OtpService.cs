using System.Buffers.Text;
using System.Security.Cryptography;
using System.Text;
using Jotter.Application;
using Microsoft.Extensions.Options;

namespace Jotter.Infrastructure;

// Mã sáu chữ số chỉ có một triệu khả năng: SHA-256 thuần bị dò ngược ngay nếu lộ bảng OTP.
// HMAC với khoá dẫn xuất từ Jwt:Secret buộc kẻ tấn công phải có cả secret của server.
public sealed class OtpService : IOtpService
{
    public const int HashLength = 64;

    private const int TicketByteLength = 32;
    private static readonly byte[] KeyDerivationInfo = "jotter-otp-hmac"u8.ToArray();
    private static readonly int CodeUpperBound = (int)Math.Pow(10, IOtpService.CodeLength);

    private readonly byte[] _hmacKey;

    public OtpService(IOptions<JwtOptions> options)
    {
        _hmacKey = HKDF.DeriveKey(
            HashAlgorithmName.SHA256,
            Encoding.UTF8.GetBytes(options.Value.Secret),
            outputLength: 32,
            info: KeyDerivationInfo);
    }

    public string GenerateCode() =>
        RandomNumberGenerator.GetInt32(CodeUpperBound).ToString($"D{IOtpService.CodeLength}");

    public string GenerateTicket() => Base64Url.EncodeToString(RandomNumberGenerator.GetBytes(TicketByteLength));

    public string Hash(string value) =>
        Convert.ToHexStringLower(HMACSHA256.HashData(_hmacKey, Encoding.UTF8.GetBytes(value)));
}

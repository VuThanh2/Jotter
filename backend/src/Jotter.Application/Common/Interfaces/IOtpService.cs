namespace Jotter.Application;

public interface IOtpService
{
    const int CodeLength = 6;

    string GenerateCode();

    string GenerateTicket();

    // Băm tất định: VerificationCode so khớp theo hash, còn resetTicket được tra cứu theo hash.
    string Hash(string value);
}

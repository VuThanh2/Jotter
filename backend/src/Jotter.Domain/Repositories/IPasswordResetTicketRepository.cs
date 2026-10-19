namespace Jotter.Domain;

public interface IPasswordResetTicketRepository
{
    Task<PasswordResetTicket?> GetByHashAsync(string ticketHash, CancellationToken ct);

    void Add(PasswordResetTicket ticket);
}

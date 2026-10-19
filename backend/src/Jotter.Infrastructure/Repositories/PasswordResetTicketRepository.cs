using Jotter.Domain;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

public sealed class PasswordResetTicketRepository(AppDbContext db) : IPasswordResetTicketRepository
{
    public Task<PasswordResetTicket?> GetByHashAsync(string ticketHash, CancellationToken ct) =>
        db.PasswordResetTickets.FirstOrDefaultAsync(t => t.TicketHash == ticketHash, ct);

    public void Add(PasswordResetTicket ticket) => db.PasswordResetTickets.Add(ticket);
}

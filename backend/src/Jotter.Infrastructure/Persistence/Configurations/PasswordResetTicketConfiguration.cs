using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

public sealed class PasswordResetTicketConfiguration : IEntityTypeConfiguration<PasswordResetTicket>
{
    public void Configure(EntityTypeBuilder<PasswordResetTicket> builder)
    {
        builder.ToTable("password_reset_tickets");

        builder.HasKey(t => t.Id);
        builder.Property(t => t.Id).ValueGeneratedNever();

        builder.Property(t => t.TicketHash).HasMaxLength(OtpService.HashLength).IsRequired();

        builder.HasOne<User>().WithMany().HasForeignKey(t => t.UserId).OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(t => t.TicketHash).IsUnique();
    }
}

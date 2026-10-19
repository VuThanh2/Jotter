using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

public sealed class NoteUnlockSessionConfiguration : IEntityTypeConfiguration<NoteUnlockSession>
{
    public void Configure(EntityTypeBuilder<NoteUnlockSession> builder)
    {
        builder.ToTable("note_unlock_sessions");

        builder.HasKey(s => s.Id);
        builder.Property(s => s.Id).ValueGeneratedNever();

        builder.HasOne<Note>().WithMany().HasForeignKey(s => s.NoteId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<User>().WithMany().HasForeignKey(s => s.UserId).OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(s => new { s.UserId, s.NoteId, s.ExpiresAt });
        builder.HasIndex(s => new { s.NoteId, s.ExpiresAt });
    }
}

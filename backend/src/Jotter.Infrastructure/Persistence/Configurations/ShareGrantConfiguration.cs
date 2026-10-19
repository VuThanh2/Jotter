using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

public sealed class ShareGrantConfiguration : IEntityTypeConfiguration<ShareGrant>
{
    public void Configure(EntityTypeBuilder<ShareGrant> builder)
    {
        builder.ToTable("share_grants");

        builder.HasKey(g => g.Id);
        builder.Property(g => g.Id).ValueGeneratedNever();

        builder.Property(g => g.Permission).HasConversion<string>().HasMaxLength(16);

        builder.HasOne<Note>().WithMany().HasForeignKey(g => g.NoteId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<User>().WithMany().HasForeignKey(g => g.RecipientUserId).OnDelete(DeleteBehavior.Cascade);

        // Bất biến "không cấp trùng cho một người trên cùng note" khi hai request chia sẻ chạy đồng thời.
        builder.HasIndex(g => new { g.NoteId, g.RecipientUserId }).IsUnique().HasFilter("revoked_at IS NULL");
        builder.HasIndex(g => new { g.RecipientUserId, g.ChangeSeq });
        builder.HasIndex(g => g.ChangeSeq);
    }
}

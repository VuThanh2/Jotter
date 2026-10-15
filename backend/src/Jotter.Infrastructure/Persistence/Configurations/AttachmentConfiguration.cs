using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

public sealed class AttachmentConfiguration : IEntityTypeConfiguration<Attachment>
{
    public void Configure(EntityTypeBuilder<Attachment> builder)
    {
        builder.ToTable("attachments");

        builder.HasKey(a => a.Id);
        builder.Property(a => a.Id).ValueGeneratedNever();

        builder.Property(a => a.FileName).HasMaxLength(Attachment.MaxFileNameLength).IsRequired();
        builder.Property(a => a.MimeType).HasMaxLength(127).IsRequired();
        builder.Property(a => a.StorageKey).HasMaxLength(StorageKeys.MaxLength).IsRequired();

        builder.HasOne<User>().WithMany().HasForeignKey(a => a.UploadedBy).OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(a => a.NoteId);
        builder.HasIndex(a => a.StorageKey).IsUnique();
        builder.HasIndex(a => a.ChangeSeq);
    }
}

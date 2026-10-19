using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

public sealed class NoteConfiguration : IEntityTypeConfiguration<Note>
{
    public void Configure(EntityTypeBuilder<Note> builder)
    {
        builder.ToTable("notes");

        builder.HasKey(n => n.Id);
        builder.Property(n => n.Id).ValueGeneratedNever();

        builder.Property(n => n.Title).HasMaxLength(NoteTitle.MaxLength).IsRequired();
        builder.Property(n => n.Content).IsRequired();
        builder.Property(n => n.SearchTitle).IsRequired();
        builder.Property(n => n.SearchContent).IsRequired();
        builder.Property(n => n.PasswordHash).HasMaxLength(256);

        // Domain kiểm baseVersion trên bản đã load; token này chặn hai lần ghi đồng thời cùng dựa trên một version.
        builder.Property(n => n.Version).IsConcurrencyToken();

        builder.HasOne<User>().WithMany().HasForeignKey(n => n.OwnerId).OnDelete(DeleteBehavior.Cascade);

        // Chỉ là tham chiếu để hiển thị huy hiệu: note gốc bị dọn vật lý thì bản sao vẫn sống.
        builder.HasOne<Note>().WithMany().HasForeignKey(n => n.ConflictOfNoteId).OnDelete(DeleteBehavior.SetNull);

        builder.HasMany(n => n.Labels).WithOne().HasForeignKey(link => link.NoteId).OnDelete(DeleteBehavior.Cascade);
        builder.Navigation(n => n.Labels).HasField("_labels").UsePropertyAccessMode(PropertyAccessMode.Field);

        builder.HasMany(n => n.Attachments).WithOne().HasForeignKey(a => a.NoteId).OnDelete(DeleteBehavior.Cascade);
        builder.Navigation(n => n.Attachments).HasField("_attachments").UsePropertyAccessMode(PropertyAccessMode.Field);

        builder.HasOne(n => n.Summary)
            .WithOne()
            .HasForeignKey<NoteSummary>(s => s.NoteId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(n => new { n.OwnerId, n.ChangeSeq });
        builder.HasIndex(n => n.ChangeSeq);
    }
}

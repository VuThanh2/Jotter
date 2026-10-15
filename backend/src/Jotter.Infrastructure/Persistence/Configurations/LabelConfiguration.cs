using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

public sealed class LabelConfiguration : IEntityTypeConfiguration<Label>
{
    public void Configure(EntityTypeBuilder<Label> builder)
    {
        builder.ToTable("labels");

        builder.HasKey(l => l.Id);
        builder.Property(l => l.Id).ValueGeneratedNever();

        builder.Property(l => l.Name).HasMaxLength(LabelName.MaxLength).IsRequired();

        builder.HasOne<User>().WithMany().HasForeignKey(l => l.OwnerId).OnDelete(DeleteBehavior.Cascade);

        // Chặn trùng tên khi hai request tạo nhãn chạy đồng thời; trùng không phân biệt hoa thường do repository kiểm.
        builder.HasIndex(l => new { l.OwnerId, l.Name }).IsUnique().HasFilter("deleted_at IS NULL");
        builder.HasIndex(l => new { l.OwnerId, l.ChangeSeq });
    }
}

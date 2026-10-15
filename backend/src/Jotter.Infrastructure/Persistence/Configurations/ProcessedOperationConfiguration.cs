using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

public sealed class ProcessedOperationConfiguration : IEntityTypeConfiguration<ProcessedOperation>
{
    public void Configure(EntityTypeBuilder<ProcessedOperation> builder)
    {
        builder.ToTable("processed_operations");

        // opId do client sinh nên khoá theo cả userId: người khác không thể dùng trùng opId để đọc response của mình.
        builder.HasKey(o => new { o.UserId, o.OperationId });

        builder.Property(o => o.ContentType).HasMaxLength(128);
        builder.Property(o => o.ResponseBody).IsRequired();

        builder.HasIndex(o => o.ProcessedAt);
    }
}

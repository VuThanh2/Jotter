using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

public sealed class PurgeCheckpointConfiguration : IEntityTypeConfiguration<PurgeCheckpoint>
{
    public void Configure(EntityTypeBuilder<PurgeCheckpoint> builder)
    {
        builder.ToTable("purge_checkpoints");

        builder.HasKey(c => c.Id);
        builder.Property(c => c.Id).ValueGeneratedNever();
    }
}

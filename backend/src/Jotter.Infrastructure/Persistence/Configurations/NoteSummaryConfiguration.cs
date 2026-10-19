using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

// Bảng riêng thay vì cột của notes: sinh tóm tắt không được làm dòng note bị sửa, nên không nhận changeSeq mới.
public sealed class NoteSummaryConfiguration : IEntityTypeConfiguration<NoteSummary>
{
    public void Configure(EntityTypeBuilder<NoteSummary> builder)
    {
        builder.ToTable("note_summaries");

        builder.HasKey(s => s.NoteId);

        builder.Property(s => s.SummaryText).IsRequired();
    }
}

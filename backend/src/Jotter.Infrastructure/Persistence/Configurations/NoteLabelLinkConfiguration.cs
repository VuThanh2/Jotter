using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

public sealed class NoteLabelLinkConfiguration : IEntityTypeConfiguration<NoteLabelLink>
{
    public void Configure(EntityTypeBuilder<NoteLabelLink> builder)
    {
        builder.ToTable("note_labels");

        builder.HasKey(link => new { link.NoteId, link.LabelId });

        builder.HasOne<Label>().WithMany().HasForeignKey(link => link.LabelId).OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(link => link.LabelId);
    }
}

using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

// Vector lưu dạng real[] (Npgsql ánh xạ sẵn float[]); cosine tính trong C# nên không cần pgvector.
public sealed class NoteEmbeddingConfiguration : IEntityTypeConfiguration<NoteEmbedding>
{
    public void Configure(EntityTypeBuilder<NoteEmbedding> builder)
    {
        builder.ToTable("note_embeddings");

        builder.HasKey(e => new { e.NoteId, e.ChunkIndex });

        builder.Property(e => e.ChunkText).IsRequired();
        builder.Property(e => e.Vector).IsRequired();

        builder.HasOne<Note>().WithMany().HasForeignKey(e => e.NoteId).OnDelete(DeleteBehavior.Cascade);
    }
}

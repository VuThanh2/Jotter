using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

public sealed class UserPreferencesConfiguration : IEntityTypeConfiguration<UserPreferences>
{
    public void Configure(EntityTypeBuilder<UserPreferences> builder)
    {
        builder.ToTable("user_preferences");

        builder.HasKey(p => p.UserId);

        builder.Property(p => p.DefaultNoteColor).HasMaxLength(7).IsRequired();
        builder.Property(p => p.ThemeMode).HasConversion<string>().HasMaxLength(16);
        builder.Property(p => p.ListViewMode).HasConversion<string>().HasMaxLength(16);
    }
}

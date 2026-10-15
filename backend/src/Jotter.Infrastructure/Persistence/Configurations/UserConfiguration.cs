using Jotter.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Jotter.Infrastructure;

public sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("users");

        builder.Property(u => u.DisplayName).HasMaxLength(DisplayName.MaxLength).IsRequired();
        builder.Property(u => u.AvatarStorageKey).HasMaxLength(StorageKeys.MaxLength);
        builder.Property(u => u.CreatedAt).IsRequired();

        // Identity chỉ kiểm email trùng ở tầng ứng dụng; index unique chặn nốt hai lần đăng ký đồng thời.
        builder.HasIndex(u => u.NormalizedEmail).IsUnique();

        builder.HasOne(u => u.Preferences)
            .WithOne()
            .HasForeignKey<UserPreferences>(p => p.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Navigation(u => u.Preferences).IsRequired();
    }
}

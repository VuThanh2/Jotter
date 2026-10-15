using Jotter.Domain;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

// IdentityUserContext thay vì IdentityDbContext: hệ thống không dùng role nên không tạo ba bảng role bỏ trống.
public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : IdentityUserContext<User, Guid>(options)
{
    public const string ChangeSeqSequence = "change_seq";

    public DbSet<UserSession> UserSessions => Set<UserSession>();

    public DbSet<VerificationCode> VerificationCodes => Set<VerificationCode>();

    public DbSet<PasswordResetTicket> PasswordResetTickets => Set<PasswordResetTicket>();

    public DbSet<Note> Notes => Set<Note>();

    public DbSet<Attachment> Attachments => Set<Attachment>();

    public DbSet<Label> Labels => Set<Label>();

    public DbSet<ShareGrant> ShareGrants => Set<ShareGrant>();

    public DbSet<NoteUnlockSession> NoteUnlockSessions => Set<NoteUnlockSession>();

    public DbSet<NoteEmbedding> NoteEmbeddings => Set<NoteEmbedding>();

    public DbSet<ProcessedOperation> ProcessedOperations => Set<ProcessedOperation>();

    public DbSet<PurgeCheckpoint> PurgeCheckpoints => Set<PurgeCheckpoint>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.HasSequence<long>(ChangeSeqSequence);
        builder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        builder.Entity<IdentityUserClaim<Guid>>().ToTable("user_claims");
        builder.Entity<IdentityUserLogin<Guid>>().ToTable("user_logins");
        builder.Entity<IdentityUserToken<Guid>>().ToTable("user_tokens");
    }
}

using Jotter.Application;
using Jotter.Domain;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Jotter.Infrastructure;

// Tài khoản chấm bài: có note đã chia sẻ (cả hai chiều), note đang khoá và nhiều nhãn. Đi qua đúng các hành vi
// của Domain và UserManager như luồng thật, trong một transaction để không bao giờ để lại dữ liệu demo dở dang.
public sealed class DemoDataSeeder(
    AppDbContext db,
    UserManager<User> userManager,
    INotePasswordHasher notePasswordHasher,
    TimeProvider clock,
    ILogger<DemoDataSeeder> logger)
{
    public const string DemoEmail = "demo@jotter.app";
    public const string FriendEmail = "friend@jotter.app";
    public const string AccountPassword = "Demo@123";
    public const string ProtectedNotePassword = "1234";

    public async Task SeedAsync(CancellationToken ct)
    {
        if (await userManager.FindByEmailAsync(DemoEmail) is not null)
        {
            return;
        }

        var now = clock.GetUtcNow();
        await using var transaction = await db.Database.BeginTransactionAsync(ct);

        var demo = await CreateActivatedUserAsync(DemoEmail, "Người dùng Demo", now, ct);
        var friend = await CreateActivatedUserAsync(FriendEmail, "Bạn của Demo", now, ct);

        var work = AddLabel(demo, "Công việc");
        var personal = AddLabel(demo, "Cá nhân");
        var study = AddLabel(demo, "Học tập");

        var welcome = AddNote(
            demo,
            "Chào mừng đến với Jotter",
            "Ghi chú tự động lưu sau khi bạn ngừng gõ. Thử ghim, gắn nhãn, đính kèm tệp hoặc hỏi AI về các note của bạn.",
            now.AddMinutes(-50),
            personal);
        welcome.Pin(now);

        var projectPlan = AddNote(
            demo,
            "Kế hoạch dự án cuối kỳ",
            "Tuần 1: chốt kiến trúc.\nTuần 2: hoàn thiện đồng bộ ngoại tuyến.\nTuần 3: tính năng AI.\nTuần 4: kiểm thử và triển khai lên Railway.",
            now.AddMinutes(-40),
            work,
            study);

        AddNote(
            demo,
            "Danh sách mua sắm",
            "Sữa tươi, bánh mì, trứng gà, cà phê, rau cải.",
            now.AddMinutes(-30),
            personal);

        AddNote(
            demo,
            "Ôn tập Flutter",
            "Riverpod quản lý state, go_router điều hướng có guard, Drift làm kho cục bộ chạy được cả web lẫn native.",
            now.AddMinutes(-20),
            study);

        var secret = AddNote(
            demo,
            "Ghi chú bí mật",
            $"Nội dung này chỉ đọc được sau khi mở khoá bằng mật khẩu note \"{ProtectedNotePassword}\".",
            now.AddMinutes(-10),
            personal);
        secret.EnableProtection(notePasswordHasher.Hash(ProtectedNotePassword));

        var recipe = AddNote(
            friend,
            "Công thức nấu phở",
            "Hầm xương bò 6 tiếng, nướng hành và gừng, thêm quế, hồi, thảo quả. Nêm nước mắm vừa ăn.",
            now.AddMinutes(-5));

        Share(projectPlan, friend, SharePermission.Edit, now);
        Share(recipe, demo, SharePermission.ReadOnly, now);

        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);

        logger.LogInformation("Đã tạo dữ liệu demo cho {DemoEmail} và {FriendEmail}.", DemoEmail, FriendEmail);
    }

    private async Task<User> CreateActivatedUserAsync(
        string email,
        string displayName,
        DateTimeOffset now,
        CancellationToken ct)
    {
        var user = User.Create(email, displayName, now).Value;

        // Lưu user trước để xác minh email đi qua đúng đường cập nhật của Identity như luồng kích hoạt thật.
        EnsureSucceeded(await userManager.CreateAsync(user, AccountPassword));
        await db.SaveChangesAsync(ct);

        var confirmationToken = await userManager.GenerateEmailConfirmationTokenAsync(user);
        EnsureSucceeded(await userManager.ConfirmEmailAsync(user, confirmationToken));

        return user;
    }

    private Label AddLabel(User owner, string name)
    {
        var label = Label.Create(Guid.CreateVersion7(), owner.Id, name).Value;
        db.Labels.Add(label);
        return label;
    }

    private Note AddNote(User owner, string title, string content, DateTimeOffset createdAt, params Label[] labels)
    {
        var note = Note.Create(Guid.CreateVersion7(createdAt), owner.Id, title, content, createdAt).Value;
        note.SetLabels(labels.Select(label => label.Id));
        db.Notes.Add(note);
        return note;
    }

    private void Share(Note note, User recipient, SharePermission permission, DateTimeOffset now) =>
        db.ShareGrants.Add(ShareGrant.Create(note.Id, note.OwnerId, recipient.Id, permission, now).Value);

    private static void EnsureSucceeded(IdentityResult result)
    {
        if (!result.Succeeded)
        {
            var errors = string.Join("; ", result.Errors.Select(e => e.Description));
            throw new InvalidOperationException($"Không tạo được dữ liệu demo: {errors}");
        }
    }
}

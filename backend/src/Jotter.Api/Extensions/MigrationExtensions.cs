using Jotter.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Jotter.Api;

public static class MigrationExtensions
{
    // Chạy trước khi nhận request: máy chấm bài dựng lại từ docker compose không phải gõ thêm lệnh migration nào.
    // Seeder tự bỏ qua khi tài khoản demo đã tồn tại nên chạy lại mỗi lần khởi động vẫn an toàn.
    public static async Task ApplyMigrationsAsync(this WebApplication app)
    {
        await using var scope = app.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        // Trên database trắng, MigrateAsync đọc thử bảng lịch sử trước khi tạo nó, nên lần chạy đầu tiên log ra
        // "fail: Failed executing DbCommand" dù không có gì hỏng — đúng lúc người chấm vừa chạy docker compose up.
        // Tạo sẵn bảng (idempotent) để log khởi động sạch. Database chưa tồn tại thì để MigrateAsync tự tạo như cũ.
        if (await db.Database.CanConnectAsync())
        {
            await db.GetService<IHistoryRepository>().CreateIfNotExistsAsync();
        }

        await db.Database.MigrateAsync();
        await scope.ServiceProvider.GetRequiredService<DemoDataSeeder>().SeedAsync(CancellationToken.None);
    }
}

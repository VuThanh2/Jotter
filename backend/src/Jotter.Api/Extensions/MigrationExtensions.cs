using Jotter.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace Jotter.Api;

public static class MigrationExtensions
{
    // Chạy trước khi nhận request: máy chấm bài dựng lại từ docker compose không phải gõ thêm lệnh migration nào.
    // Seeder tự bỏ qua khi tài khoản demo đã tồn tại nên chạy lại mỗi lần khởi động vẫn an toàn.
    public static async Task ApplyMigrationsAsync(this WebApplication app)
    {
        await using var scope = app.Services.CreateAsyncScope();

        await scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.MigrateAsync();
        await scope.ServiceProvider.GetRequiredService<DemoDataSeeder>().SeedAsync(CancellationToken.None);
    }
}

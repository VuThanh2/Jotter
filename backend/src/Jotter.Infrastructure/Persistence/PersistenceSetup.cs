using Microsoft.EntityFrameworkCore;

namespace Jotter.Infrastructure;

// Cấu hình provider dùng chung cho runtime và design-time để migration sinh ra khớp đúng với lúc chạy.
internal static class PersistenceSetup
{
    public static void Configure(DbContextOptionsBuilder options, string connectionString) =>
        options
            .UseNpgsql(connectionString)
            .UseSnakeCaseNamingConvention();
}

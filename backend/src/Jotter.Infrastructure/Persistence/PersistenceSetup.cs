using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Jotter.Infrastructure;

// Cấu hình provider dùng chung cho runtime và design-time để migration sinh ra khớp đúng với lúc chạy.
internal static class PersistenceSetup
{
    public static void Configure(DbContextOptionsBuilder options, string connectionString) =>
        options
            .UseNpgsql(WithoutGssEncryption(connectionString))
            .UseSnakeCaseNamingConvention();

    // Npgsql mặc định thử mã hoá GSS (Kerberos) trước khi kết nối, kéo theo việc nạp libgssapi_krb5 — image aspnet
    // không có thư viện này nên lần kết nối đầu ghi lỗi "cannot open shared object file" ra log. Postgres của
    // docker compose lẫn Railway đều không dùng Kerberos, tắt đi không mất gì; SSL vẫn theo connection string.
    private static string WithoutGssEncryption(string connectionString) =>
        new NpgsqlConnectionStringBuilder(connectionString) { GssEncryptionMode = GssEncryptionMode.Disable }
            .ConnectionString;
}

using Jotter.Infrastructure.IntegrationTests;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using Testcontainers.PostgreSql;
using Xunit;

[assembly: AssemblyFixture(typeof(PostgresFixture))]

namespace Jotter.Infrastructure.IntegrationTests;

// Một container Postgres cho cả assembly. Migration chạy một lần lên database mẫu; mỗi test nhận một bản sao riêng
// (CREATE DATABASE ... TEMPLATE, rất nhanh) nên các test chạy song song không bao giờ thấy dữ liệu của nhau.
public sealed class PostgresFixture : IAsyncLifetime
{
    private const string TemplateDatabase = "jotter_template";

    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder("postgres:17-alpine").Build();

    // Postgres từ chối sao chép một template đang có phiên khác truy cập, nên các lần tạo phải nối đuôi nhau.
    private readonly SemaphoreSlim _createLock = new(1, 1);

    public async ValueTask InitializeAsync()
    {
        await _container.StartAsync();
        await ExecuteAdminAsync($"CREATE DATABASE {TemplateDatabase}");

        // Migrate qua đúng cấu hình DbContext mà ứng dụng dùng, không dựng lại cấu hình riêng cho test.
        await using (var host = new InfrastructureHost(ConnectionStringFor(TemplateDatabase)))
        {
            await host.WithScopeAsync(services => services.GetRequiredService<AppDbContext>().Database.MigrateAsync());
        }

        NpgsqlConnection.ClearAllPools();
    }

    public async Task<string> CreateDatabaseAsync()
    {
        var name = $"jotter_{Guid.NewGuid():N}";

        await _createLock.WaitAsync();
        try
        {
            await ExecuteAdminAsync($"CREATE DATABASE {name} TEMPLATE {TemplateDatabase}");
        }
        finally
        {
            _createLock.Release();
        }

        return ConnectionStringFor(name);
    }

    public async ValueTask DisposeAsync()
    {
        _createLock.Dispose();
        await _container.DisposeAsync();
    }

    private string ConnectionStringFor(string database) =>
        new NpgsqlConnectionStringBuilder(_container.GetConnectionString()) { Database = database }.ConnectionString;

    private async Task ExecuteAdminAsync(string sql)
    {
        await using var connection = new NpgsqlConnection(_container.GetConnectionString());
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }
}

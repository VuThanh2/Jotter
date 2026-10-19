using Xunit;

namespace Jotter.Infrastructure.IntegrationTests;

// xUnit tạo một instance cho mỗi test, nên mỗi test có database và thư mục lưu trữ của riêng nó.
public abstract class DatabaseTest(PostgresFixture postgres) : IAsyncLifetime
{
    internal InfrastructureHost Host { get; private set; } = null!;

    public async ValueTask InitializeAsync() => Host = await InfrastructureHost.CreateAsync(postgres);

    public ValueTask DisposeAsync() => Host.DisposeAsync();
}

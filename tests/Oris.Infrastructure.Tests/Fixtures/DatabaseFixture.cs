using Microsoft.EntityFrameworkCore;
using Oris.Infrastructure.Persistence;
using Testcontainers.PostgreSql;

namespace Oris.Infrastructure.Tests.Fixtures;

public class DatabaseFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container;

    public DatabaseFixture()
    {
        _container = new PostgreSqlBuilder()
            .WithImage("postgres:15")
            .WithDatabase("oris_test")
            .Build();
    }

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
    }

    public OrisDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<OrisDbContext>()
            .UseNpgsql(_container.GetConnectionString())
            .Options;

        return new OrisDbContext(options);
    }

    public async Task DisposeAsync()
    {
        await _container.DisposeAsync();
    }
}

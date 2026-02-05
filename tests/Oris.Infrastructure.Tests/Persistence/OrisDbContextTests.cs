using Oris.Infrastructure.Tests.Fixtures;
using Shouldly;

namespace Oris.Infrastructure.Tests.Persistence;

public class OrisDbContextTests : IClassFixture<DatabaseFixture>
{
    private readonly DatabaseFixture _fixture;

    public OrisDbContextTests(DatabaseFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public async Task CanConnect_ToDatabase_ReturnsTrue()
    {
        // Arrange
        using var context = _fixture.CreateContext();

        // Act
        var canConnect = await context.Database.CanConnectAsync();

        // Assert
        canConnect.ShouldBeTrue();
    }
}
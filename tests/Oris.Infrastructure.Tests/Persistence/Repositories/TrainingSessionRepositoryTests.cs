using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Oris.Infrastructure.Persistence.Repositories;
using Oris.Infrastructure.Tests.Fixtures;
using Shouldly;
using Xunit;

namespace Oris.Infrastructure.Tests.Persistence.Repositories;

public class TrainingSessionRepositoryTests : IClassFixture<DatabaseFixture>
{
    private readonly DatabaseFixture _fixture;

    public TrainingSessionRepositoryTests(DatabaseFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public async Task HasActiveSessionForDateAsync_ShouldReturnTrue_WhenActiveSessionExistsForDate()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var date = DateTime.UtcNow.Date;
        var session = new TrainingSession(userId, date, SessionType.Upper);
        
        using (var context = _fixture.CreateContext())
        {
            context.TrainingSessions.Add(session);
            await context.SaveChangesAsync();
        }

        using (var context = _fixture.CreateContext())
        {
            var repository = new TrainingSessionRepository(context);

            // Act
            var result = await repository.HasActiveSessionForDateAsync(userId, date);

            // Assert
            result.ShouldBeTrue();
        }
    }

    [Fact]
    public async Task HasActiveSessionForDateAsync_ShouldReturnFalse_WhenSessionIsCompleted()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var date = DateTime.UtcNow.Date;
        var session = new TrainingSession(userId, date, SessionType.Upper);
        session.Complete();
        
        using (var context = _fixture.CreateContext())
        {
            context.TrainingSessions.Add(session);
            await context.SaveChangesAsync();
        }

        using (var context = _fixture.CreateContext())
        {
            var repository = new TrainingSessionRepository(context);

            // Act
            var result = await repository.HasActiveSessionForDateAsync(userId, date);

            // Assert
            result.ShouldBeFalse();
        }
    }

    [Fact]
    public async Task HasActiveSessionForDateAsync_ShouldReturnFalse_WhenNoSessionExistsForDate()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var date = DateTime.UtcNow.Date;
        
        using (var context = _fixture.CreateContext())
        {
            var repository = new TrainingSessionRepository(context);

            // Act
            var result = await repository.HasActiveSessionForDateAsync(userId, date);

            // Assert
            result.ShouldBeFalse();
        }
    }
}

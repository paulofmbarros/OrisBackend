using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Entities;

public class TrainingSessionTests
{
    [Fact]
    public void AddExercise_ShouldThrowInvalidOperationException_WhenSessionIsCompleted()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var session = new TrainingSession(userId, DateTime.UtcNow, SessionType.Upper);
        session.Complete();

        // Act & Assert
        Should.Throw<InvalidOperationException>(() =>
            session.AddExercise(Guid.NewGuid(), 3, 8, 12))
            .Message.ShouldContain("completed");
    }

    [Fact]
    public void AddPerformance_ShouldAddPerformance_WhenValid()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var session = new TrainingSession(userId, DateTime.UtcNow, SessionType.Upper);
        var exerciseId = Guid.NewGuid();

        // Act
        session.AddPerformance(exerciseId);

        // Assert
        session.Performances.ShouldContain(p => p.ExerciseId == exerciseId);
    }

    [Fact]
    public void AddPerformance_ShouldThrowInvalidOperationException_WhenSessionIsCompleted()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var session = new TrainingSession(userId, DateTime.UtcNow, SessionType.Upper);
        session.Complete();
        var exerciseId = Guid.NewGuid();

        // Act & Assert
        Should.Throw<InvalidOperationException>(() =>
            session.AddPerformance(exerciseId))
            .Message.ShouldContain("completed");
    }

    [Fact]
    public void AddSetToPerformance_ShouldAddSet_WhenValid()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var session = new TrainingSession(userId, DateTime.UtcNow, SessionType.Upper);
        var exerciseId = Guid.NewGuid();

        // Act
        session.AddSetToPerformance(exerciseId, 100, 10, 8);

        // Assert
        var performance = session.Performances.First(p => p.ExerciseId == exerciseId);
        performance.Sets.Count.ShouldBe(1);
        performance.Sets.First().Weight.ShouldBe(100);
    }

    [Fact]
    public void AddSetToPerformance_ShouldThrowInvalidOperationException_WhenSessionIsCompleted()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var session = new TrainingSession(userId, DateTime.UtcNow, SessionType.Upper);
        session.Complete();

        // Act & Assert
        Should.Throw<InvalidOperationException>(() =>
            session.AddSetToPerformance(Guid.NewGuid(), 100, 10))
            .Message.ShouldContain("completed");
    }

    [Fact]
    public void Complete_ShouldSetIsCompletedToTrue()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var session = new TrainingSession(userId, DateTime.UtcNow, SessionType.Upper);

        // Act
        session.Complete();

        // Assert
        session.IsCompleted.ShouldBeTrue();
    }

    [Fact]
    public void Constructor_ShouldInitializeWithIsCompletedFalse()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var session = new TrainingSession(userId, DateTime.UtcNow, SessionType.Upper);

        // Assert
        session.IsCompleted.ShouldBeFalse();
        session.PlannedExercises.ShouldBeEmpty();
    }
}

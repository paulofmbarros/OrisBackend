using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Entities;

public class TrainingSessionTests
{
    [Fact]
    public void Constructor_ShouldSetProperties_WhenValid()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var scheduledDate = DateTime.UtcNow.Date.AddDays(1);

        // Act
        var session = new TrainingSession(userId, scheduledDate, SessionType.Upper);

        // Assert
        session.UserId.ShouldBe(userId);
        session.ScheduledDate.ShouldBe(scheduledDate);
        session.Type.ShouldBe(SessionType.Upper);
        session.IsCompleted.ShouldBeFalse();
        session.PlannedExercises.ShouldBeEmpty();
        session.Performances.ShouldBeEmpty();
    }

    [Fact]
    public void AddExercise_ShouldAddPlannedExercise_WhenValid()
    {
        // Arrange
        var session = new TrainingSession(Guid.NewGuid(), DateTime.UtcNow, SessionType.Upper);
        var exerciseId = Guid.NewGuid();
        var initialUpdatedAt = session.UpdatedAt;

        // Act
        session.AddExercise(exerciseId, 3, 8, 12);

        // Assert
        session.PlannedExercises.Count.ShouldBe(1);
        var plannedExercise = session.PlannedExercises.First();
        plannedExercise.ExerciseId.ShouldBe(exerciseId);
        plannedExercise.Sets.ShouldBe(3);
        plannedExercise.TargetRepRange.Min.ShouldBe(8);
        plannedExercise.TargetRepRange.Max.ShouldBe(12);
        session.UpdatedAt.ShouldBeGreaterThanOrEqualTo(initialUpdatedAt);
    }

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
    public void AddPerformance_ShouldNotAddDuplicatePerformance_WhenExerciseAlreadyExists()
    {
        // Arrange
        var session = new TrainingSession(Guid.NewGuid(), DateTime.UtcNow, SessionType.Upper);
        var exerciseId = Guid.NewGuid();

        session.AddPerformance(exerciseId);
        var updatedAtAfterFirstAdd = session.UpdatedAt;

        // Act
        session.AddPerformance(exerciseId);

        // Assert
        session.Performances.Count.ShouldBe(1);
        session.UpdatedAt.ShouldBe(updatedAtAfterFirstAdd);
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
    public void AddPerformance_ShouldThrowArgumentException_WhenExerciseIdIsEmpty()
    {
        // Arrange
        var session = new TrainingSession(Guid.NewGuid(), DateTime.UtcNow, SessionType.Upper);

        // Act & Assert
        Should.Throw<ArgumentException>(() => session.AddPerformance(Guid.Empty));
    }

    [Fact]
    public void AddSetToPerformance_ShouldCreatePerformanceAndAddSet_WhenPerformanceDoesNotExist()
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
    public void AddSetToPerformance_ShouldThrowArgumentException_WhenExerciseIdIsEmpty()
    {
        // Arrange
        var session = new TrainingSession(Guid.NewGuid(), DateTime.UtcNow, SessionType.Upper);

        // Act & Assert
        Should.Throw<ArgumentException>(() =>
            session.AddSetToPerformance(Guid.Empty, 100, 10));
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
    public void AddExercise_ShouldThrowArgumentException_WhenSetsIsInvalid()
    {
        // Arrange
        var session = new TrainingSession(Guid.NewGuid(), DateTime.UtcNow, SessionType.Upper);

        // Act & Assert
        Should.Throw<ArgumentException>(() => session.AddExercise(Guid.NewGuid(), 0, 8, 12));
        Should.Throw<ArgumentException>(() => session.AddExercise(Guid.NewGuid(), 21, 8, 12));
    }

    [Fact]
    public void AddExercise_ShouldThrowArgumentException_WhenExerciseIdIsEmpty()
    {
        // Arrange
        var session = new TrainingSession(Guid.NewGuid(), DateTime.UtcNow, SessionType.Upper);

        // Act & Assert
        Should.Throw<ArgumentException>(() => session.AddExercise(Guid.Empty, 3, 8, 12));
    }

    [Fact]
    public void AddSetToPerformance_ShouldThrowInvalidOperationException_WhenMaxSetsReached()
    {
        // Arrange
        var session = new TrainingSession(Guid.NewGuid(), DateTime.UtcNow, SessionType.Upper);
        var exerciseId = Guid.NewGuid();

        for (int i = 0; i < 20; i++)
        {
            session.AddSetToPerformance(exerciseId, 100, 10);
        }

        // Act & Assert
        Should.Throw<InvalidOperationException>(() =>
            session.AddSetToPerformance(exerciseId, 100, 10))
            .Message.ShouldContain("Maximum number of sets");
    }

    [Fact]
    public void AddSetToPerformance_ShouldThrowArgumentException_WhenWeightIsNegative()
    {
        // Arrange
        var session = new TrainingSession(Guid.NewGuid(), DateTime.UtcNow, SessionType.Upper);

        // Act & Assert
        Should.Throw<ArgumentException>(() =>
            session.AddSetToPerformance(Guid.NewGuid(), -1, 10));
    }
}

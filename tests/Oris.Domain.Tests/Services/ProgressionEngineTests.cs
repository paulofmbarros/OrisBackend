using Oris.Domain.Entities;
using Oris.Domain.Services;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Services;

public class ProgressionEngineTests
{
    private readonly ProgressionEngine _engine = new();

    [Fact]
    public void CalculateNextState_ShouldIncreaseWeight_WhenAllSetsHitTarget()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var exerciseId = Guid.NewGuid();
        var currentState = new ProgressionState(userId, exerciseId, 100, 10);
        var performance = new ExercisePerformance(Guid.NewGuid(), exerciseId);
        performance.AddSet(100, 12);
        performance.AddSet(100, 12);

        // Act
        var result = _engine.CalculateNextState(currentState, performance, 12);

        // Assert
        result.LastWeight.ShouldBe(102.5);
        result.LastReps.ShouldBe(12);
    }

    [Fact]
    public void CalculateNextState_ShouldKeepLatestSet_WhenNotAllSetsHitTarget()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var exerciseId = Guid.NewGuid();
        var currentState = new ProgressionState(userId, exerciseId, 100, 10);
        var performance = new ExercisePerformance(Guid.NewGuid(), exerciseId);
        performance.AddSet(100, 12);
        performance.AddSet(100, 11);

        // Act
        var result = _engine.CalculateNextState(currentState, performance, 12);

        // Assert
        result.LastWeight.ShouldBe(100);
        result.LastReps.ShouldBe(11);
    }

    [Fact]
    public void CalculateNextState_ShouldReturnCurrentState_WhenPerformanceHasNoSets()
    {
        // Arrange
        var currentState = new ProgressionState(Guid.NewGuid(), Guid.NewGuid(), 100, 10);
        var performance = new ExercisePerformance(Guid.NewGuid(), Guid.NewGuid());

        // Act
        var result = _engine.CalculateNextState(currentState, performance, 12);

        // Assert
        ReferenceEquals(result, currentState).ShouldBeTrue();
        result.LastWeight.ShouldBe(100);
        result.LastReps.ShouldBe(10);
    }
}

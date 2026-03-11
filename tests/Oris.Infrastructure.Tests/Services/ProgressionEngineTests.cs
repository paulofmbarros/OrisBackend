using Oris.Domain.Entities;
using Oris.Infrastructure.Services;
using Shouldly;
using Xunit;

namespace Oris.Infrastructure.Tests.Services;

public class ProgressionEngineTests
{
    private readonly ProgressionEngine _engine;

    public ProgressionEngineTests()
    {
        _engine = new ProgressionEngine();
    }

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

        var targetReps = 12;

        // Act
        var result = _engine.CalculateNextState(currentState, performance, targetReps);

        // Assert
        result.IsSuccess.ShouldBeTrue();
        result.Value.LastWeight.ShouldBe(102.5);
        result.Value.LastReps.ShouldBe(12);
    }

    [Fact]
    public void CalculateNextState_ShouldNotIncreaseWeight_WhenNotAllSetsHitTarget()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var exerciseId = Guid.NewGuid();
        var currentState = new ProgressionState(userId, exerciseId, 100, 10);
        var performance = new ExercisePerformance(Guid.NewGuid(), exerciseId);
        performance.AddSet(100, 12);
        performance.AddSet(100, 11); // Failed target

        var targetReps = 12;

        // Act
        var result = _engine.CalculateNextState(currentState, performance, targetReps);

        // Assert
        result.IsSuccess.ShouldBeTrue();
        result.Value.LastWeight.ShouldBe(100);
        result.Value.LastReps.ShouldBe(11);
    }
}

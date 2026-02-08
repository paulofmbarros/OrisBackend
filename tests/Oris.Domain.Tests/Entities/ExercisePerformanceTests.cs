using Oris.Domain.Entities;
using Oris.Domain.ValueObjects;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Entities;

public class ExercisePerformanceTests
{
    [Fact]
    public void AddSet_ShouldAddSetPerformanceToList()
    {
        // Arrange
        var trainingSessionId = Guid.NewGuid();
        var exerciseId = Guid.NewGuid();
        var performance = new ExercisePerformance(trainingSessionId, exerciseId);

        // Act
        performance.AddSet(100, 10, 8.5);

        // Assert
        performance.Sets.Count.ShouldBe(1);
        performance.Sets.First().Weight.ShouldBe(100);
        performance.Sets.First().Reps.ShouldBe(10);
        performance.Sets.First().Rpe.ShouldBe(8.5);
    }

    [Fact]
    public void AddSet_ShouldUpdateUpdatedAt()
    {
        // Arrange
        var performance = new ExercisePerformance(Guid.NewGuid(), Guid.NewGuid());
        var initialUpdatedAt = performance.UpdatedAt;

        // Act
        performance.AddSet(50, 12);

        // Assert
        performance.UpdatedAt.ShouldBeGreaterThanOrEqualTo(initialUpdatedAt);
    }
}

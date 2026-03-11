using Oris.Domain.Entities;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Entities;

public class ProgressionStateTests
{
    [Fact]
    public void Constructor_ShouldSetProperties_WhenValid()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var exerciseId = Guid.NewGuid();

        // Act
        var state = new ProgressionState(userId, exerciseId, 100, 8, 8.5);

        // Assert
        state.UserId.ShouldBe(userId);
        state.ExerciseId.ShouldBe(exerciseId);
        state.LastWeight.ShouldBe(100);
        state.LastReps.ShouldBe(8);
        state.LastRpe.ShouldBe(8.5);
    }

    [Fact]
    public void UpdateProgress_ShouldUpdateProperties()
    {
        // Arrange
        var state = new ProgressionState(Guid.NewGuid(), Guid.NewGuid(), 100, 8, 8.5);

        // Act
        state.UpdateProgress(105, 10, 9);

        // Assert
        state.LastWeight.ShouldBe(105);
        state.LastReps.ShouldBe(10);
        state.LastRpe.ShouldBe(9);
    }

    [Fact]
    public void UpdateProgress_ShouldUpdateUpdatedAt()
    {
        // Arrange
        var state = new ProgressionState(Guid.NewGuid(), Guid.NewGuid(), 100, 8);
        var initialUpdatedAt = state.UpdatedAt;

        // Act
        state.UpdateProgress(102.5, 9, null);

        // Assert
        state.UpdatedAt.ShouldBeGreaterThanOrEqualTo(initialUpdatedAt);
    }
}

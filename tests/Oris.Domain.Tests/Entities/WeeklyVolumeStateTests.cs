using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Entities;

public class WeeklyVolumeStateTests
{
    [Fact]
    public void AddSets_ShouldIncrementCurrentSets()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var state = new WeeklyVolumeState(userId, MuscleGroup.Chest, 10);

        // Act
        state.AddSets(3);

        // Assert
        state.CurrentSets.ShouldBe(3);
    }

    [Fact]
    public void Reset_ShouldSetCurrentSetsToZero()
    {
        // Arrange
        var state = new WeeklyVolumeState(Guid.NewGuid(), MuscleGroup.Back, 12);
        state.AddSets(5);

        // Act
        state.Reset();

        // Assert
        state.CurrentSets.ShouldBe(0);
    }

    [Fact]
    public void Constructor_ShouldInitializeCorrectly()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var muscleGroup = MuscleGroup.Quads;
        var targetSets = 15;

        // Act
        var state = new WeeklyVolumeState(userId, muscleGroup, targetSets);

        // Assert
        state.UserId.ShouldBe(userId);
        state.MuscleGroup.ShouldBe(muscleGroup);
        state.TargetSets.ShouldBe(targetSets);
        state.CurrentSets.ShouldBe(0);
    }
}

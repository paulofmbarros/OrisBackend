using Oris.Domain.Entities;
using Oris.Domain.ValueObjects;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Entities;

public class PlannedExerciseTests
{
    [Fact]
    public void Constructor_ShouldSetProperties_WhenValid()
    {
        // Arrange
        var sessionId = Guid.NewGuid();
        var exerciseId = Guid.NewGuid();
        var sets = 3;
        var repRange = new RepetitionRange(8, 12);

        // Act
        var planned = new PlannedExercise(sessionId, exerciseId, sets, repRange);

        // Assert
        planned.TrainingSessionId.ShouldBe(sessionId);
        planned.ExerciseId.ShouldBe(exerciseId);
        planned.Sets.ShouldBe(sets);
        planned.TargetRepRange.ShouldBe(repRange);
    }

    [Fact]
    public void Constructor_ShouldThrowArgumentException_WhenSetsIsZeroOrNegative()
    {
        // Act & Assert
        Should.Throw<ArgumentException>(() =>
            new PlannedExercise(Guid.NewGuid(), Guid.NewGuid(), 0, new RepetitionRange(8, 12)));
    }

    [Fact]
    public void Constructor_ShouldThrowArgumentNullException_WhenRepRangeIsNull()
    {
        // Act & Assert
        Should.Throw<ArgumentNullException>(() =>
            new PlannedExercise(Guid.NewGuid(), Guid.NewGuid(), 3, null!));
    }
}

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
        var planned = new PlannedExercise(sessionId, exerciseId, sets, repRange, 0);

        // Assert
        planned.TrainingSessionId.ShouldBe(sessionId);
        planned.ExerciseId.ShouldBe(exerciseId);
        planned.Sets.ShouldBe(sets);
        planned.TargetRepRange.ShouldBe(repRange);
        planned.Order.ShouldBe(0);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void Constructor_ShouldThrowArgumentException_WhenSetsIsZeroOrNegative(int sets)
    {
        // Act & Assert
        Should.Throw<ArgumentException>(() =>
            new PlannedExercise(Guid.NewGuid(), Guid.NewGuid(), sets, new RepetitionRange(8, 12), 0));
    }

    [Fact]
    public void Constructor_ShouldThrowArgumentNullException_WhenRepRangeIsNull()
    {
        // Act & Assert
        Should.Throw<ArgumentNullException>(() =>
            new PlannedExercise(Guid.NewGuid(), Guid.NewGuid(), 3, null!, 0));
    }
}

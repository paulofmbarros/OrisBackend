using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Entities;

public class ExerciseTests
{
    [Fact]
    public void Constructor_ShouldSetProperties_WhenValid()
    {
        // Arrange
        var name = "Bench Press";
        var classification = ExerciseClassification.Compound;

        // Act
        var exercise = new Exercise(name, classification);

        // Assert
        exercise.Name.ShouldBe(name);
        exercise.Classification.ShouldBe(classification);
    }

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData(null)]
    public void Constructor_ShouldThrowArgumentException_WhenNameIsInvalid(string? name)
    {
        // Act & Assert
        Should.Throw<ArgumentException>(() => new Exercise(name!, ExerciseClassification.Accessory));
    }
}

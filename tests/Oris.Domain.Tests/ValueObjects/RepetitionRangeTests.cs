using Oris.Domain.ValueObjects;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.ValueObjects;

public class RepetitionRangeTests
{
    [Fact]
    public void Constructor_ShouldSetProperties_WhenValid()
    {
        // Arrange & Act
        var range = new RepetitionRange(8, 12);

        // Assert
        range.Min.ShouldBe(8);
        range.Max.ShouldBe(12);
    }

    [Fact]
    public void Constructor_ShouldThrowArgumentException_WhenMinIsNegative()
    {
        // Act & Assert
        Should.Throw<ArgumentException>(() => new RepetitionRange(-1, 10))
            .Message.ShouldContain("negative");
    }

    [Fact]
    public void Constructor_ShouldThrowArgumentException_WhenMaxIsLessThanMin()
    {
        // Act & Assert
        Should.Throw<ArgumentException>(() => new RepetitionRange(10, 5))
            .Message.ShouldContain("less than minimum");
    }

    [Fact]
    public void Constructor_ShouldAllowEqualMinAndMax()
    {
        // Arrange & Act
        var range = new RepetitionRange(10, 10);

        // Assert
        range.Min.ShouldBe(10);
        range.Max.ShouldBe(10);
    }
}

using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Entities;

public class UserTests
{
    [Fact]
    public void Constructor_ShouldSetEmail()
    {
        // Arrange
        var email = "test@example.com";

        // Act
        var user = new User(email);

        // Assert
        user.Email.ShouldBe(email);
    }

    [Fact]
    public void Constructor_ShouldThrowArgumentException_WhenEmailIsEmpty()
    {
        // Act & Assert
        Should.Throw<ArgumentException>(() => new User(""))
            .Message.ShouldContain("empty");
    }
}

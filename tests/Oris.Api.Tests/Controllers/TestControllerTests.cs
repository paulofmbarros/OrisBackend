using Microsoft.AspNetCore.Mvc;
using Oris.Application.Abstractions;
using Oris.WebApplication.Controllers;
using Shouldly;
using Xunit;

namespace Oris.Api.Tests.Controllers;

public class TestControllerTests
{
    [Fact]
    public void GetProtected_ReturnsOkWithAuthorizedMessageAndUserId()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var controller = new TestController(new StubCurrentUserService(userId));

        // Act
        var result = controller.GetProtected();

        // Assert
        var ok = result.ShouldBeOfType<OkObjectResult>();
        var payload = ok.Value.ShouldNotBeNull();

        payload.GetType().GetProperty("Message")?.GetValue(payload)?.ToString()
            .ShouldBe("You are authorized");
        payload.GetType().GetProperty("UserId")?.GetValue(payload)?.ToString()
            .ShouldBe(userId.ToString());
    }

    [Fact]
    public void GetPublic_ReturnsOkWithPublicMessage()
    {
        // Arrange
        var controller = new TestController(new StubCurrentUserService(null));

        // Act
        var result = controller.GetPublic();

        // Assert
        var ok = result.ShouldBeOfType<OkObjectResult>();
        var payload = ok.Value.ShouldNotBeNull();

        payload.GetType().GetProperty("Message")?.GetValue(payload)?.ToString()
            .ShouldBe("This is public");
    }

    private sealed class StubCurrentUserService : ICurrentUserService
    {
        public StubCurrentUserService(Guid? userId)
        {
            UserId = userId;
        }

        public Guid? UserId { get; }
    }
}

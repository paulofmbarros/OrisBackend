using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Moq;
using Oris.Infrastructure.Identity;
using Shouldly;

namespace Oris.Infrastructure.Tests.Identity;

public class CurrentUserServiceTests
{
    private readonly Mock<IHttpContextAccessor> _httpContextAccessorMock;
    private readonly CurrentUserService _service;

    public CurrentUserServiceTests()
    {
        _httpContextAccessorMock = new Mock<IHttpContextAccessor>();
        _service = new CurrentUserService(_httpContextAccessorMock.Object);
    }

    [Fact]
    public void UserId_WhenUserIsAuthenticated_ReturnsUserId()
    {
        // Arrange
        var userId = Guid.NewGuid().ToString();
        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, userId)
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        var claimsPrincipal = new ClaimsPrincipal(identity);
        var httpContext = new DefaultHttpContext { User = claimsPrincipal };

        _httpContextAccessorMock.Setup(x => x.HttpContext).Returns(httpContext);

        // Act
        var result = _service.UserId;

        // Assert
        result.ShouldBe(userId);
    }

    [Fact]
    public void UserId_WhenUserIsNotAuthenticated_ReturnsNull()
    {
        // Arrange
        var httpContext = new DefaultHttpContext { User = new ClaimsPrincipal() };

        _httpContextAccessorMock.Setup(x => x.HttpContext).Returns(httpContext);

        // Act
        var result = _service.UserId;

        // Assert
        result.ShouldBeNull();
    }

    [Fact]
    public void UserId_WhenHttpContextIsNull_ReturnsNull()
    {
        // Arrange
        _httpContextAccessorMock.Setup(x => x.HttpContext).Returns((HttpContext?)null);

        // Act
        var result = _service.UserId;

        // Assert
        result.ShouldBeNull();
    }
}

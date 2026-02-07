using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Oris.Application.Abstractions;

namespace Oris.WebApplication.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TestController : ControllerBase
{
    private readonly ICurrentUserService _currentUserService;

    public TestController(ICurrentUserService currentUserService)
    {
        _currentUserService = currentUserService;
    }

    [HttpGet("protected")]
    [Authorize]
    public IActionResult GetProtected()
    {
        return Ok(new
        {
            Message = "You are authorized",
            UserId = _currentUserService.UserId
        });
    }

    [HttpGet("public")]
    [AllowAnonymous]
    public IActionResult GetPublic()
    {
        return Ok(new { Message = "This is public" });
    }
}

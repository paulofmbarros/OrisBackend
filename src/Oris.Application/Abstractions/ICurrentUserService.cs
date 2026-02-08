namespace Oris.Application.Abstractions;

public interface ICurrentUserService
{
    Guid? UserId { get; }
}

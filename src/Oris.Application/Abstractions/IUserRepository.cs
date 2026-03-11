using Oris.Domain.Entities;

namespace Oris.Application.Abstractions;

public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<User?> GetByExternalIdAsync(string externalId, CancellationToken cancellationToken = default);
    void Add(User user);
    void Update(User user);
}

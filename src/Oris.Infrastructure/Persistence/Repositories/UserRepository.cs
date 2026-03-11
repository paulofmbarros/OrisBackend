using Microsoft.EntityFrameworkCore;
using Oris.Application.Abstractions;
using Oris.Domain.Entities;

namespace Oris.Infrastructure.Persistence.Repositories;

public class UserRepository : IUserRepository
{
    private readonly OrisDbContext _context;

    public UserRepository(OrisDbContext context)
    {
        _context = context;
    }

    public async Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Users.FirstOrDefaultAsync(u => u.Id == id, cancellationToken);
    }

    public async Task<User?> GetByExternalIdAsync(string externalId, CancellationToken cancellationToken = default)
    {
        // Implementation depends on where externalId is stored in User entity
        // For now, returning null as it's not in the base entity yet
        return null;
    }

    public void Add(User user)
    {
        _context.Users.Add(user);
    }

    public void Update(User user)
    {
        _context.Users.Update(user);
    }
}

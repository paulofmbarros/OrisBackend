using Oris.Application.Abstractions;

namespace Oris.Infrastructure.Persistence;

public class UnitOfWork : IUnitOfWork
{
    private readonly OrisDbContext _context;

    public UnitOfWork(OrisDbContext context)
    {
        _context = context;
    }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }
}

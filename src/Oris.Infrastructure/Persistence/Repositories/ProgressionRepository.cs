using Microsoft.EntityFrameworkCore;
using Oris.Application.Abstractions;
using Oris.Domain.Entities;

namespace Oris.Infrastructure.Persistence.Repositories;

public class ProgressionRepository : IProgressionRepository
{
    private readonly OrisDbContext _context;

    public ProgressionRepository(OrisDbContext context)
    {
        _context = context;
    }

    public async Task<ProgressionState?> GetByUserIdAndExerciseIdAsync(Guid userId, Guid exerciseId, CancellationToken cancellationToken = default)
    {
        return await _context.ProgressionStates
            .FirstOrDefaultAsync(p => p.UserId == userId && p.ExerciseId == exerciseId, cancellationToken);
    }

    public async Task<List<ProgressionState>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.ProgressionStates
            .Where(p => p.UserId == userId)
            .ToListAsync(cancellationToken);
    }

    public void Add(ProgressionState state)
    {
        _context.ProgressionStates.Add(state);
    }

    public void Update(ProgressionState state)
    {
        _context.ProgressionStates.Update(state);
    }
}

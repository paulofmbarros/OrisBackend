using Microsoft.EntityFrameworkCore;
using Oris.Application.Abstractions;
using Oris.Domain.Entities;
using Oris.Domain.Enums;

namespace Oris.Infrastructure.Persistence.Repositories;

public class VolumeRepository : IVolumeRepository
{
    private readonly OrisDbContext _context;

    public VolumeRepository(OrisDbContext context)
    {
        _context = context;
    }

    public async Task<WeeklyVolumeState?> GetByUserIdAndMuscleGroupAsync(Guid userId, MuscleGroup muscleGroup, CancellationToken cancellationToken = default)
    {
        return await _context.WeeklyVolumeStates
            .FirstOrDefaultAsync(v => v.UserId == userId && v.MuscleGroup == muscleGroup, cancellationToken);
    }

    public async Task<List<WeeklyVolumeState>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.WeeklyVolumeStates
            .Where(v => v.UserId == userId)
            .ToListAsync(cancellationToken);
    }

    public void Add(WeeklyVolumeState state)
    {
        _context.WeeklyVolumeStates.Add(state);
    }

    public void Update(WeeklyVolumeState state)
    {
        _context.WeeklyVolumeStates.Update(state);
    }
}

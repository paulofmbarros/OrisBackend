using Microsoft.EntityFrameworkCore;
using Oris.Application.Abstractions;
using Oris.Domain.Entities;
using Oris.Domain.Enums;

namespace Oris.Infrastructure.Persistence.Repositories;

public class ExerciseRepository : IExerciseRepository
{
    private readonly OrisDbContext _context;

    public ExerciseRepository(OrisDbContext context)
    {
        _context = context;
    }

    public async Task<Exercise?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Exercises.FirstOrDefaultAsync(e => e.Id == id, cancellationToken);
    }

    public async Task<List<Exercise>> GetByMuscleGroupAsync(MuscleGroup muscleGroup, CancellationToken cancellationToken = default)
    {
        return await _context.Exercises
            .Where(e => e.MuscleGroup == muscleGroup)
            .ToListAsync(cancellationToken);
    }

    public async Task<List<Exercise>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        return await _context.Exercises.ToListAsync(cancellationToken);
    }
}

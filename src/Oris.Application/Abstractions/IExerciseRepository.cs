using Oris.Domain.Entities;
using Oris.Domain.Enums;

namespace Oris.Application.Abstractions;

public interface IExerciseRepository
{
    Task<Exercise?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<List<Exercise>> GetByIdsAsync(IEnumerable<Guid> ids, CancellationToken cancellationToken = default);
    Task<List<Exercise>> GetByMuscleGroupAsync(MuscleGroup muscleGroup, CancellationToken cancellationToken = default);
    Task<List<Exercise>> GetAllAsync(CancellationToken cancellationToken = default);
}

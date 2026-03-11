using Oris.Domain.Entities;

namespace Oris.Application.Abstractions;

public interface IProgressionRepository
{
    Task<ProgressionState?> GetByUserIdAndExerciseIdAsync(Guid userId, Guid exerciseId, CancellationToken cancellationToken = default);
    Task<List<ProgressionState>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    void Add(ProgressionState state);
    void Update(ProgressionState state);
}

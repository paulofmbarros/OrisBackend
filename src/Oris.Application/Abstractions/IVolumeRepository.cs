using Oris.Domain.Entities;
using Oris.Domain.Enums;

namespace Oris.Application.Abstractions;

public interface IVolumeRepository
{
    Task<WeeklyVolumeState?> GetByUserIdAndMuscleGroupAsync(Guid userId, MuscleGroup muscleGroup, CancellationToken cancellationToken = default);
    Task<List<WeeklyVolumeState>> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    void Add(WeeklyVolumeState state);
    void Update(WeeklyVolumeState state);
}

using Oris.Application.Common.Models;
using Oris.Domain.Entities;

namespace Oris.Application.Abstractions;

/// <summary>
/// Filters and weights candidate exercises based on current volume states.
/// </summary>
public interface IVolumeController
{
    /// <summary>
    /// Filters candidate <see cref="Exercise"/> entities based on safety thresholds in <see cref="WeeklyVolumeState"/>.
    /// </summary>
    /// <param name="candidates">Initial collection of candidate exercises.</param>
    /// <param name="currentVolumes">Current weekly volume state for relevant muscle groups.</param>
    /// <returns>A <see cref="Result{T}"/> containing a filtered (and potentially weighted) collection of <see cref="Exercise"/>.</returns>
    Result<IEnumerable<Exercise>> FilterAndWeightExercises(
        IEnumerable<Exercise> candidates,
        IEnumerable<WeeklyVolumeState> currentVolumes);
}

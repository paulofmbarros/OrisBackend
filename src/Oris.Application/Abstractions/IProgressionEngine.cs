using Oris.Application.Common.Models;
using Oris.Domain.Entities;

namespace Oris.Application.Abstractions;

/// <summary>
/// Calculates progression based on recent performance and current state.
/// </summary>
public interface IProgressionEngine
{
    /// <summary>
    /// Calculates the next <see cref="ProgressionState"/> based on current state and recent performance.
    /// </summary>
    /// <param name="currentState">The current progression state for a given exercise.</param>
    /// <param name="performance">The latest exercise performance recorded.</param>
    /// <returns>A <see cref="Result{T}"/> containing the updated <see cref="ProgressionState"/>.</returns>
    Result<ProgressionState> CalculateNextState(
        ProgressionState currentState,
        ExercisePerformance performance,
        int targetReps);
}

using Oris.Application.Abstractions;
using Oris.Application.Common.Models;
using Oris.Domain.Entities;

namespace Oris.Infrastructure.Services;

public class ProgressionEngine : IProgressionEngine
{
    public Result<ProgressionState> CalculateNextState(ProgressionState currentState, ExercisePerformance performance, int targetReps)
    {
        if (performance.Sets == null || !performance.Sets.Any())
            return Result<ProgressionState>.Success(currentState);

        var allSetsHitTarget = performance.Sets.All(s => s.Reps >= targetReps);

        if (allSetsHitTarget)
        {
            // Simple logic: increase weight by 2.5 and keep target reps
            currentState.UpdateProgress(currentState.LastWeight + 2.5, targetReps, performance.Sets.LastOrDefault()?.Rpe);
        }
        else
        {
            // Just update with latest performance
            var lastSet = performance.Sets.Last();
            currentState.UpdateProgress(lastSet.Weight, lastSet.Reps, lastSet.Rpe);
        }

        return Result<ProgressionState>.Success(currentState);
    }
}

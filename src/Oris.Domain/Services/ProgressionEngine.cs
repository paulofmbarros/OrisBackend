using Oris.Domain.Entities;

namespace Oris.Domain.Services;

public class ProgressionEngine : IProgressionEngine
{
    public ProgressionState CalculateNextState(ProgressionState currentState, ExercisePerformance performance, int targetReps)
    {
        if (!performance.Sets.Any())
        {
            return currentState;
        }

        var allSetsHitTarget = performance.Sets.All(s => s.Reps >= targetReps);

        if (allSetsHitTarget)
        {
            currentState.UpdateProgress(currentState.LastWeight + 2.5, targetReps, performance.Sets.LastOrDefault()?.Rpe);
        }
        else
        {
            var lastSet = performance.Sets.Last();
            currentState.UpdateProgress(lastSet.Weight, lastSet.Reps, lastSet.Rpe);
        }

        return currentState;
    }
}

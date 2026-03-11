using Oris.Domain.Entities;

namespace Oris.Domain.Services;

public interface IProgressionEngine
{
    ProgressionState CalculateNextState(
        ProgressionState currentState,
        ExercisePerformance performance,
        int targetReps);
}

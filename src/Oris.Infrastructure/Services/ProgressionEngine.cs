using Oris.Application.Abstractions;
using Oris.Application.Common.Models;
using Oris.Domain.Entities;

namespace Oris.Infrastructure.Services;

public class ProgressionEngine : IProgressionEngine
{
    public Result<ProgressionState> CalculateNextState(ProgressionState currentState, ExercisePerformance performance)
    {
        // Placeholder implementation
        return Result<ProgressionState>.Success(currentState);
    }
}

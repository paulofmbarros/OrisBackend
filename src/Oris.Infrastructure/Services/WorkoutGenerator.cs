using Oris.Application.Abstractions;
using Oris.Application.Common.Models;
using Oris.Domain.Entities;
using Oris.Domain.Enums;

namespace Oris.Infrastructure.Services;

public class WorkoutGenerator : IWorkoutGenerator
{
    public Task<Result<TrainingSession>> GenerateWorkoutAsync(User user, SessionType type, DateTime scheduledDate, CancellationToken cancellationToken = default)
    {
        // Placeholder implementation
        var session = new TrainingSession(user.Id, scheduledDate, type);
        return Task.FromResult(Result<TrainingSession>.Success(session));
    }
}

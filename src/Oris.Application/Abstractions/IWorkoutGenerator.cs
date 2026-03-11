using Oris.Application.Common.Models;
using Oris.Domain.Entities;
using Oris.Domain.Enums;

namespace Oris.Application.Abstractions;

/// <summary>
/// Generates a <see cref="TrainingSession"/> for a given <see cref="User"/> based on current state and volume requirements.
/// </summary>
public interface IWorkoutGenerator
{
    /// <summary>
    /// Generates a training session asynchronously.
    /// </summary>
    /// <param name="user">The user for whom to generate the session.</param>
    /// <param name="type">The type of the training session (Upper/Lower).</param>
    /// <param name="scheduledDate">The date when the session is scheduled.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A <see cref="Result{T}"/> containing the generated <see cref="TrainingSession"/>.</returns>
    Task<Result<TrainingSession>> GenerateWorkoutAsync(
        User user,
        SessionType type,
        DateTime scheduledDate,
        CancellationToken cancellationToken = default);
}

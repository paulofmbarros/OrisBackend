using Oris.Domain.Entities;

namespace Oris.Application.Abstractions;

public interface ITrainingSessionRepository
{
    Task<TrainingSession?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<TrainingSession?> GetActiveSessionByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<bool> HasActiveSessionForDateAsync(Guid userId, DateTime date, CancellationToken cancellationToken = default);
    Task<TrainingSession?> GetLastCompletedSessionByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);
    void Add(TrainingSession session);
    void Update(TrainingSession session);
}

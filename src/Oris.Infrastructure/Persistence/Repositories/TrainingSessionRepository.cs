using Microsoft.EntityFrameworkCore;
using Oris.Application.Abstractions;
using Oris.Domain.Entities;

namespace Oris.Infrastructure.Persistence.Repositories;

public class TrainingSessionRepository : ITrainingSessionRepository
{
    private readonly OrisDbContext _context;

    public TrainingSessionRepository(OrisDbContext context)
    {
        _context = context;
    }

    public async Task<TrainingSession?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.TrainingSessions
            .Include(s => s.PlannedExercises)
            .Include(s => s.Performances)
            .FirstOrDefaultAsync(s => s.Id == id, cancellationToken);
    }

    public async Task<TrainingSession?> GetActiveSessionByUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.TrainingSessions
            .Include(s => s.PlannedExercises)
            .Include(s => s.Performances)
            .FirstOrDefaultAsync(s => s.UserId == userId && s.CompletedAt == null, cancellationToken);
    }

    public async Task<bool> HasActiveSessionForDateAsync(Guid userId, DateTime date, CancellationToken cancellationToken = default)
    {
        var dateOnly = date.Date;
        return await _context.TrainingSessions
            .AnyAsync(s => s.UserId == userId && s.ScheduledDate.Date == dateOnly && s.CompletedAt == null, cancellationToken);
    }

    public async Task<TrainingSession?> GetLastCompletedSessionByUserIdAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.TrainingSessions
            .Include(s => s.PlannedExercises)
            .Where(s => s.UserId == userId && s.CompletedAt != null)
            .OrderByDescending(s => s.ScheduledDate)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public void Add(TrainingSession session)
    {
        _context.TrainingSessions.Add(session);
    }

    public void Update(TrainingSession session)
    {
        _context.TrainingSessions.Update(session);
    }
}

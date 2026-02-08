using Oris.Domain.Entities.Base;
using Oris.Domain.Enums;

namespace Oris.Domain.Entities;

public class TrainingSession : AggregateRoot
{
    public Guid UserId { get; private set; }
    public DateTime ScheduledDate { get; private set; }
    public SessionType Type { get; private set; }
    public bool IsCompleted { get; private set; }

    private readonly List<PlannedExercise> _plannedExercises = new();
    public IReadOnlyCollection<PlannedExercise> PlannedExercises => _plannedExercises.AsReadOnly();

    private readonly List<ExercisePerformance> _performances = new();
    public IReadOnlyCollection<ExercisePerformance> Performances => _performances.AsReadOnly();

    public TrainingSession(Guid userId, DateTime scheduledDate, SessionType type)
    {
        UserId = userId;
        ScheduledDate = scheduledDate;
        Type = type;
        IsCompleted = false;
    }

    public void AddExercise(Guid exerciseId, int sets, int minReps, int maxReps)
    {
        if (IsCompleted)
            throw new InvalidOperationException("Cannot add exercises to a completed session.");

        var plannedExercise = new PlannedExercise(Id, exerciseId, sets, new(minReps, maxReps));
        _plannedExercises.Add(plannedExercise);
        UpdatedAt = DateTime.UtcNow;
    }

    public void AddPerformance(Guid exerciseId)
    {
        if (IsCompleted)
            throw new InvalidOperationException("Cannot add performances to a completed session.");

        if (_performances.Any(p => p.ExerciseId == exerciseId))
            return;

        var performance = new ExercisePerformance(Id, exerciseId);
        _performances.Add(performance);
        UpdatedAt = DateTime.UtcNow;
    }

    public void AddSetToPerformance(Guid exerciseId, double weight, int reps, double? rpe = null)
    {
        if (IsCompleted)
            throw new InvalidOperationException("Cannot add sets to a completed session.");

        var performance = _performances.FirstOrDefault(p => p.ExerciseId == exerciseId);
        if (performance == null)
        {
            performance = new ExercisePerformance(Id, exerciseId);
            _performances.Add(performance);
        }

        performance.AddSet(weight, reps, rpe);
        UpdatedAt = DateTime.UtcNow;
    }

    public void Complete()
    {
        if (IsCompleted)
            return;

        IsCompleted = true;
        UpdatedAt = DateTime.UtcNow;
    }

    // Required for EF Core
    private TrainingSession() : base()
    {
    }
}

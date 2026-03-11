using Oris.Domain.Entities.Base;
using Oris.Domain.Enums;

namespace Oris.Domain.Entities;

public class TrainingSession : AggregateRoot
{
    public Guid UserId { get; private set; }
    public DateTime ScheduledDate { get; private set; }
    public SessionType Type { get; private set; }
    public DateTime? LockedAt { get; private set; }
    public DateTime? CompletedAt { get; private set; }
    public bool IsCompleted => CompletedAt.HasValue;
    public bool IsLocked => LockedAt.HasValue;

    private readonly List<PlannedExercise> _plannedExercises = new();
    public IReadOnlyCollection<PlannedExercise> PlannedExercises => _plannedExercises.AsReadOnly();

    private readonly List<ExercisePerformance> _performances = new();
    public IReadOnlyCollection<ExercisePerformance> Performances => _performances.AsReadOnly();

    public TrainingSession(Guid userId, DateTime scheduledDate, SessionType type)
    {
        UserId = userId;
        ScheduledDate = scheduledDate;
        Type = type;
    }

    public void AddExercise(Guid exerciseId, int sets, int minReps, int maxReps, int order, double? suggestedLoad = null, int? restTimeSeconds = null)
    {
        if (IsLocked)
            throw new InvalidOperationException("Cannot add exercises to a locked session.");

        if (exerciseId == Guid.Empty)
            throw new ArgumentException("Exercise ID cannot be empty.", nameof(exerciseId));

        if (sets is <= 0 or > 20)
            throw new ArgumentException("Number of sets must be between 1 and 20.", nameof(sets));

        var plannedExercise = new PlannedExercise(Id, exerciseId, sets, new(minReps, maxReps), order, suggestedLoad, restTimeSeconds);
        _plannedExercises.Add(plannedExercise);
        UpdatedAt = DateTime.UtcNow;
    }

    public void AddPerformance(Guid exerciseId)
    {
        if (IsCompleted)
            throw new InvalidOperationException("Cannot add performances to a completed session.");

        if (exerciseId == Guid.Empty)
            throw new ArgumentException("Exercise ID cannot be empty.", nameof(exerciseId));

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

        if (!IsLocked)
        {
            LockedAt = DateTime.UtcNow;
        }

        if (exerciseId == Guid.Empty)
            throw new ArgumentException("Exercise ID cannot be empty.", nameof(exerciseId));

        var performance = _performances.FirstOrDefault(p => p.ExerciseId == exerciseId);
        if (performance == null)
        {
            performance = new ExercisePerformance(Id, exerciseId);
            _performances.Add(performance);
        }

        if (performance.Sets.Count >= 20)
            throw new InvalidOperationException("Maximum number of sets (20) reached for this exercise.");

        performance.AddSet(weight, reps, rpe);
        UpdatedAt = DateTime.UtcNow;
    }

    public void Complete()
    {
        if (IsCompleted)
            return;

        if (!IsLocked)
        {
            LockedAt = DateTime.UtcNow;
        }

        CompletedAt = DateTime.UtcNow;
        UpdatedAt = DateTime.UtcNow;
    }

    // Required for EF Core
    private TrainingSession() : base()
    {
    }
}

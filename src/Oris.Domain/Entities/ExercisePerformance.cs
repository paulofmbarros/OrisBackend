using Oris.Domain.Entities.Base;
using Oris.Domain.ValueObjects;

namespace Oris.Domain.Entities;

public class ExercisePerformance : Entity
{
    public Guid TrainingSessionId { get; private set; }
    public Guid ExerciseId { get; private set; }

    private readonly List<SetPerformance> _sets = new();
    public IReadOnlyCollection<SetPerformance> Sets => _sets.AsReadOnly();

    public ExercisePerformance(Guid trainingSessionId, Guid exerciseId)
    {
        TrainingSessionId = trainingSessionId;
        ExerciseId = exerciseId;
    }

    internal void AddSet(double weight, int reps, double? rpe = null)
    {
        _sets.Add(new SetPerformance(weight, reps, rpe));
        UpdatedAt = DateTime.UtcNow;
    }

    // Required for EF Core
    private ExercisePerformance() : base()
    {
    }
}

using Oris.Domain.Entities.Base;

namespace Oris.Domain.Entities;

public class ProgressionState : AggregateRoot
{
    public Guid UserId { get; private set; }
    public Guid ExerciseId { get; private set; }
    public double LastWeight { get; private set; }
    public int LastReps { get; private set; }
    public double? LastRpe { get; private set; }

    public ProgressionState(Guid userId, Guid exerciseId, double lastWeight, int lastReps, double? lastRpe = null)
    {
        UserId = userId;
        ExerciseId = exerciseId;
        LastWeight = lastWeight;
        LastReps = lastReps;
        LastRpe = lastRpe;
    }

    public void UpdateProgress(double weight, int reps, double? rpe)
    {
        LastWeight = weight;
        LastReps = reps;
        LastRpe = rpe;
        UpdatedAt = DateTime.UtcNow;
    }

    // Required for EF Core
    private ProgressionState() : base()
    {
    }
}

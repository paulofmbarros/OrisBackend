using Oris.Domain.Entities.Base;
using Oris.Domain.ValueObjects;

namespace Oris.Domain.Entities;

public class PlannedExercise : Entity
{
    public Guid TrainingSessionId { get; private set; }
    public Guid ExerciseId { get; private set; }
    public int Sets { get; private set; }
    public RepetitionRange TargetRepRange { get; private set; }

    public PlannedExercise(Guid trainingSessionId, Guid exerciseId, int sets, RepetitionRange targetRepRange)
    {
        if (sets <= 0)
            throw new ArgumentException("Number of sets must be greater than zero.", nameof(sets));

        TrainingSessionId = trainingSessionId;
        ExerciseId = exerciseId;
        Sets = sets;
        TargetRepRange = targetRepRange ?? throw new ArgumentNullException(nameof(targetRepRange));
    }

    // Required for EF Core
    private PlannedExercise() : base()
    {
        TargetRepRange = null!;
    }
}

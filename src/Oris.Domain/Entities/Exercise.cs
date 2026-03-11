using Oris.Domain.Entities.Base;
using Oris.Domain.Enums;

namespace Oris.Domain.Entities;

public class Exercise : Entity
{
    public string Name { get; private set; }
    public ExerciseClassification Classification { get; private set; }
    public MuscleGroup MuscleGroup { get; private set; }

    public Exercise(string name, ExerciseClassification classification, MuscleGroup muscleGroup)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Exercise name cannot be empty.", nameof(name));

        Name = name;
        Classification = classification;
        MuscleGroup = muscleGroup;
    }

    // Required for EF Core
    private Exercise() : base()
    {
        Name = null!;
    }
}

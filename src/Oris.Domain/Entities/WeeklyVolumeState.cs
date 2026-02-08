using Oris.Domain.Entities.Base;
using Oris.Domain.Enums;

namespace Oris.Domain.Entities;

public class WeeklyVolumeState : AggregateRoot
{
    public Guid UserId { get; private set; }
    public MuscleGroup MuscleGroup { get; private set; }
    public int CurrentSets { get; private set; }
    public int TargetSets { get; private set; }

    public WeeklyVolumeState(Guid userId, MuscleGroup muscleGroup, int targetSets)
    {
        UserId = userId;
        MuscleGroup = muscleGroup;
        TargetSets = targetSets;
        CurrentSets = 0;
    }

    public void AddSets(int sets)
    {
        CurrentSets += sets;
        UpdatedAt = DateTime.UtcNow;
    }

    public void Reset()
    {
        CurrentSets = 0;
        UpdatedAt = DateTime.UtcNow;
    }

    // Required for EF Core
    private WeeklyVolumeState() : base()
    {
    }
}

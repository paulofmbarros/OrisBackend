using Oris.Domain.Entities;
using Oris.Domain.Enums;

namespace Oris.Domain.Services;

public interface IWorkoutGenerator
{
    TrainingSession GenerateWorkout(
        User user,
        SessionType type,
        DateTime scheduledDate,
        IEnumerable<Exercise> availableExercises,
        TrainingSession? lastSession = null,
        IEnumerable<ProgressionState>? progressionStates = null,
        IEnumerable<WeeklyVolumeState>? volumeStates = null);
}

using Oris.Domain.Entities;
using Oris.Domain.Enums;

namespace Oris.Domain.Services;

public class WorkoutGenerator : IWorkoutGenerator
{
    public TrainingSession GenerateWorkout(User user, SessionType type, DateTime scheduledDate, IEnumerable<Exercise> availableExercises)
    {
        var session = new TrainingSession(user.Id, scheduledDate, type);

        foreach (var muscleGroup in GetMuscleGroups(type))
        {
            var exercise = availableExercises.FirstOrDefault(e => e.MuscleGroup == muscleGroup);
            if (exercise != null)
            {
                session.AddExercise(exercise.Id, 3, 8, 12);
            }
        }

        return session;
    }

    private static IReadOnlyList<MuscleGroup> GetMuscleGroups(SessionType type) =>
        type == SessionType.Upper
            ? [MuscleGroup.Chest, MuscleGroup.Back, MuscleGroup.Shoulders]
            : [MuscleGroup.Quads, MuscleGroup.Hamstrings, MuscleGroup.Glutes];
}

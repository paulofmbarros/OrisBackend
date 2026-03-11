using Oris.Application.Abstractions;
using Oris.Application.Common.Models;
using Oris.Domain.Entities;
using Oris.Domain.Enums;

namespace Oris.Infrastructure.Services;

public class WorkoutGenerator : IWorkoutGenerator
{
    private readonly IExerciseRepository _exerciseRepository;

    public WorkoutGenerator(IExerciseRepository exerciseRepository)
    {
        _exerciseRepository = exerciseRepository;
    }

    public async Task<Result<TrainingSession>> GenerateWorkoutAsync(User user, SessionType type, DateTime scheduledDate, CancellationToken cancellationToken = default)
    {
        var session = new TrainingSession(user.Id, scheduledDate, type);

        var muscleGroups = type == SessionType.Upper
            ? new[] { MuscleGroup.Chest, MuscleGroup.Back, MuscleGroup.Shoulders }
            : new[] { MuscleGroup.Quads, MuscleGroup.Hamstrings, MuscleGroup.Glutes };

        foreach (var muscleGroup in muscleGroups)
        {
            var exercises = await _exerciseRepository.GetByMuscleGroupAsync(muscleGroup, cancellationToken);
            var exercise = exercises.FirstOrDefault();

            if (exercise != null)
            {
                // Basic logic: 3 sets of 8-12 reps
                session.AddExercise(exercise.Id, 3, 8, 12);
            }
        }

        return Result<TrainingSession>.Success(session);
    }
}

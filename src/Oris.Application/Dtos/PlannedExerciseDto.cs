namespace Oris.Application.Dtos;

public record PlannedExerciseDto(
    Guid Id,
    Guid ExerciseId,
    string ExerciseName,
    int TargetSets,
    int MinReps,
    int MaxReps,
    int Order,
    double? SuggestedLoad,
    int? RestTimeSeconds);

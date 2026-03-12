namespace Oris.Application.Dtos;

public record TrainingSessionDto(
    Guid Id,
    DateTime Date,
    string SessionType,
    bool IsCompleted,
    DateTime? LockedAt,
    DateTime? CompletedAt,
    List<PlannedExerciseDto> PlannedExercises,
    List<ExercisePerformanceDto> Performances);

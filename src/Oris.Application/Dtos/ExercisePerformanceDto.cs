namespace Oris.Application.Dtos;

public record ExercisePerformanceDto(Guid Id, Guid ExerciseId, string ExerciseName, List<SetPerformanceDto> Sets);

using Oris.Application.Dtos;
using Oris.Domain.Entities;

namespace Oris.Application.Common.Mapping;

public static class MappingExtensions
{
    public static TrainingSessionDto ToDto(this TrainingSession session, IDictionary<Guid, string> exerciseNames)
    {
        var plannedExercises = session.PlannedExercises.Select(pe => pe.ToDto(exerciseNames)).ToList();
        var performances = session.Performances.Select(p => p.ToDto(exerciseNames)).ToList();

        return new TrainingSessionDto(
            session.Id,
            session.ScheduledDate,
            session.Type.ToString(),
            session.IsCompleted,
            session.LockedAt,
            session.CompletedAt,
            plannedExercises,
            performances);
    }

    public static PlannedExerciseDto ToDto(this PlannedExercise pe, IDictionary<Guid, string> exerciseNames)
    {
        return new PlannedExerciseDto(
            pe.Id,
            pe.ExerciseId,
            exerciseNames.TryGetValue(pe.ExerciseId, out var name) ? name : "Unknown Exercise",
            pe.Sets,
            pe.TargetRepRange.Min,
            pe.TargetRepRange.Max,
            pe.Order,
            pe.SuggestedLoad,
            pe.RestTimeSeconds);
    }

    public static ExercisePerformanceDto ToDto(this ExercisePerformance p, IDictionary<Guid, string> exerciseNames)
    {
        return new ExercisePerformanceDto(
            p.Id,
            p.ExerciseId,
            exerciseNames.TryGetValue(p.ExerciseId, out var name) ? name : "Unknown Exercise",
            p.Sets.Select(s => s.ToDto()).ToList());
    }

    public static SetPerformanceDto ToDto(this Oris.Domain.ValueObjects.SetPerformance s)
    {
        return new SetPerformanceDto(
            Guid.NewGuid(), // Placeholder ID for the set
            s.Weight,
            s.Reps,
            s.Rpe);
    }
}

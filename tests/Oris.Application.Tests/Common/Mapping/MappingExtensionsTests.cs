using Oris.Application.Common.Mapping;
using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Oris.Domain.ValueObjects;
using Shouldly;

namespace Oris.Application.Tests.Common.Mapping;

public class MappingExtensionsTests
{
    [Fact]
    public void TrainingSession_ToDto_ShouldMapSessionAndNestedCollections()
    {
        var scheduledDate = new DateTime(2025, 1, 15, 10, 30, 0, DateTimeKind.Utc);
        var userId = Guid.NewGuid();
        var plannedExerciseId = Guid.NewGuid();
        var performedExerciseId = Guid.NewGuid();
        var session = new TrainingSession(userId, scheduledDate, SessionType.Upper);

        session.AddExercise(plannedExerciseId, 3, 8, 10, 1, 75.5, 120);
        session.AddSetToPerformance(performedExerciseId, 80, 6, 8.5);
        session.Complete();

        var exerciseNames = new Dictionary<Guid, string>
        {
            [plannedExerciseId] = "Bench Press"
        };

        var dto = session.ToDto(exerciseNames);

        dto.Id.ShouldBe(session.Id);
        dto.Date.ShouldBe(scheduledDate);
        dto.SessionType.ShouldBe(nameof(SessionType.Upper));
        dto.IsCompleted.ShouldBeTrue();
        dto.LockedAt.ShouldBe(session.LockedAt);
        dto.CompletedAt.ShouldBe(session.CompletedAt);

        dto.PlannedExercises.ShouldHaveSingleItem();
        var plannedExercise = session.PlannedExercises.Single();
        var plannedExerciseDto = dto.PlannedExercises.Single();
        plannedExerciseDto.Id.ShouldBe(plannedExercise.Id);
        plannedExerciseDto.ExerciseId.ShouldBe(plannedExerciseId);
        plannedExerciseDto.ExerciseName.ShouldBe("Bench Press");
        plannedExerciseDto.TargetSets.ShouldBe(3);
        plannedExerciseDto.MinReps.ShouldBe(8);
        plannedExerciseDto.MaxReps.ShouldBe(10);
        plannedExerciseDto.Order.ShouldBe(1);
        plannedExerciseDto.SuggestedLoad.ShouldBe(75.5);
        plannedExerciseDto.RestTimeSeconds.ShouldBe(120);

        dto.Performances.ShouldHaveSingleItem();
        var performance = session.Performances.Single();
        var performanceDto = dto.Performances.Single();
        performanceDto.Id.ShouldBe(performance.Id);
        performanceDto.ExerciseId.ShouldBe(performedExerciseId);
        performanceDto.ExerciseName.ShouldBe("Unknown Exercise");
        performanceDto.Sets.ShouldHaveSingleItem();
        performanceDto.Sets.Single().Id.ShouldNotBe(Guid.Empty);
        performanceDto.Sets.Single().Weight.ShouldBe(80);
        performanceDto.Sets.Single().Reps.ShouldBe(6);
        performanceDto.Sets.Single().Rpe.ShouldBe(8.5);
    }

    [Fact]
    public void PlannedExercise_ToDto_ShouldUseFallbackName_WhenExerciseNameIsMissing()
    {
        var exerciseId = Guid.NewGuid();
        var plannedExercise = new PlannedExercise(
            Guid.NewGuid(),
            exerciseId,
            4,
            new RepetitionRange(5, 8),
            2,
            50,
            90);

        var dto = plannedExercise.ToDto(new Dictionary<Guid, string>());

        dto.Id.ShouldBe(plannedExercise.Id);
        dto.ExerciseId.ShouldBe(exerciseId);
        dto.ExerciseName.ShouldBe("Unknown Exercise");
        dto.TargetSets.ShouldBe(4);
        dto.MinReps.ShouldBe(5);
        dto.MaxReps.ShouldBe(8);
        dto.Order.ShouldBe(2);
        dto.SuggestedLoad.ShouldBe(50);
        dto.RestTimeSeconds.ShouldBe(90);
    }

    [Fact]
    public void ExercisePerformance_ToDto_ShouldUseProvidedName_WhenExerciseNameExists()
    {
        var session = new TrainingSession(Guid.NewGuid(), DateTime.UtcNow, SessionType.Lower);
        var exerciseId = Guid.NewGuid();

        session.AddSetToPerformance(exerciseId, 42.5, 12);

        var performance = session.Performances.Single();
        var dto = performance.ToDto(new Dictionary<Guid, string> { [exerciseId] = "Squat" });

        dto.Id.ShouldBe(performance.Id);
        dto.ExerciseId.ShouldBe(exerciseId);
        dto.ExerciseName.ShouldBe("Squat");
        dto.Sets.ShouldHaveSingleItem();
        dto.Sets.Single().Weight.ShouldBe(42.5);
        dto.Sets.Single().Reps.ShouldBe(12);
        dto.Sets.Single().Rpe.ShouldBeNull();
    }

    [Fact]
    public void SetPerformance_ToDto_ShouldGeneratePlaceholderId_AndPreserveValues()
    {
        var set = new SetPerformance(55, 10, 7);

        var dto = set.ToDto();

        dto.Id.ShouldNotBe(Guid.Empty);
        dto.Weight.ShouldBe(55);
        dto.Reps.ShouldBe(10);
        dto.Rpe.ShouldBe(7);
    }
}

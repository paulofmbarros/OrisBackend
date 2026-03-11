using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Oris.Domain.Services;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Services;

public class WorkoutGeneratorTests
{
    private readonly WorkoutGenerator _generator = new();

    [Fact]
    public void GenerateWorkout_ShouldPlanUpperBodySession_FromMatchingExercises()
    {
        // Arrange
        var user = new User("test@test.com");
        var chest = new Exercise("Bench Press", ExerciseClassification.Compound, MuscleGroup.Chest);
        var back = new Exercise("Barbell Row", ExerciseClassification.Compound, MuscleGroup.Back);
        var shoulders = new Exercise("Overhead Press", ExerciseClassification.Compound, MuscleGroup.Shoulders);
        var legs = new Exercise("Squat", ExerciseClassification.Compound, MuscleGroup.Quads);
        var availableExercises = new[] { chest, back, shoulders, legs };

        // Act
        var session = _generator.GenerateWorkout(user, SessionType.Upper, DateTime.UtcNow, availableExercises);

        // Assert
        session.Type.ShouldBe(SessionType.Upper);
        session.PlannedExercises.Count.ShouldBe(3);
        session.PlannedExercises.Select(x => x.ExerciseId).ToList()
            .ShouldBe(new[] { chest.Id, back.Id, shoulders.Id }, ignoreOrder: true);
        session.PlannedExercises.All(x => x.Sets == 3).ShouldBeTrue();
        session.PlannedExercises.All(x => x.TargetRepRange.Min == 8 && x.TargetRepRange.Max == 12).ShouldBeTrue();
    }

    [Fact]
    public void GenerateWorkout_ShouldPlanLowerBodySession_FromMatchingExercises()
    {
        // Arrange
        var user = new User("test@test.com");
        var quads = new Exercise("Squat", ExerciseClassification.Compound, MuscleGroup.Quads);
        var hamstrings = new Exercise("Romanian Deadlift", ExerciseClassification.Compound, MuscleGroup.Hamstrings);
        var glutes = new Exercise("Hip Thrust", ExerciseClassification.Compound, MuscleGroup.Glutes);
        var chest = new Exercise("Bench Press", ExerciseClassification.Compound, MuscleGroup.Chest);
        var availableExercises = new[] { quads, hamstrings, glutes, chest };

        // Act
        var session = _generator.GenerateWorkout(user, SessionType.Lower, DateTime.UtcNow, availableExercises);

        // Assert
        session.Type.ShouldBe(SessionType.Lower);
        session.PlannedExercises.Count.ShouldBe(3);
        session.PlannedExercises.Select(x => x.ExerciseId).ToList()
            .ShouldBe(new[] { quads.Id, hamstrings.Id, glutes.Id }, ignoreOrder: true);
    }

    [Fact]
    public void GenerateWorkout_ShouldSkipMuscleGroups_WhenNoExerciseExists()
    {
        // Arrange
        var user = new User("test@test.com");
        var chest = new Exercise("Bench Press", ExerciseClassification.Compound, MuscleGroup.Chest);
        var availableExercises = new[] { chest };

        // Act
        var session = _generator.GenerateWorkout(user, SessionType.Upper, DateTime.UtcNow, availableExercises);

        // Assert
        session.PlannedExercises.Count.ShouldBe(1);
        session.PlannedExercises.Single().ExerciseId.ShouldBe(chest.Id);
    }
}

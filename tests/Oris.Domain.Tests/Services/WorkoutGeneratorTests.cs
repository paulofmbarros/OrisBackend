using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Oris.Domain.Services;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Services;

public class WorkoutGeneratorTests
{
    private readonly WorkoutGenerator _sut;
    private readonly User _user;
    private readonly List<Exercise> _exercises;

    public WorkoutGeneratorTests()
    {
        _sut = new WorkoutGenerator();
        _user = new User("test@example.com");
        _user.SetAvailableEquipment(new List<Equipment> { Equipment.Barbell, Equipment.Dumbbell, Equipment.Bodyweight });

        _exercises = new List<Exercise>
        {
            new Exercise("Bench Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush),
            new Exercise("Dumbbell Flyes", ExerciseClassification.Accessory, MuscleGroup.Chest, MovementPattern.Isolation),
            new Exercise("Overhead Press", ExerciseClassification.Compound, MuscleGroup.Shoulders, MovementPattern.VerticalPush),
            new Exercise("Lateral Raises", ExerciseClassification.Accessory, MuscleGroup.Shoulders, MovementPattern.Isolation),
            new Exercise("Barbell Row", ExerciseClassification.Compound, MuscleGroup.Back, MovementPattern.HorizontalPull),
            new Exercise("Face Pulls", ExerciseClassification.Accessory, MuscleGroup.Back, MovementPattern.Isolation),
            new Exercise("Squat", ExerciseClassification.Compound, MuscleGroup.Quads, MovementPattern.KneeDominant),
            new Exercise("Leg Extension", ExerciseClassification.Accessory, MuscleGroup.Quads, MovementPattern.Isolation),
            new Exercise("Deadlift", ExerciseClassification.Compound, MuscleGroup.Hamstrings, MovementPattern.HipDominant),
            new Exercise("Leg Curl", ExerciseClassification.Accessory, MuscleGroup.Hamstrings, MovementPattern.Isolation),
            new Exercise("Hip Thrust", ExerciseClassification.Accessory, MuscleGroup.Glutes, MovementPattern.HipDominant)
        };

        // Assign equipment to Bench Press for testing
        _exercises[0].SetMetadata(MovementPattern.HorizontalPush, new List<Equipment> { Equipment.Barbell, Equipment.Bench });
    }

    [Fact]
    public void GenerateWorkout_ShouldAlternateSplit_WhenTypeIsNone()
    {
        // Arrange
        var lastSession = new TrainingSession(_user.Id, DateTime.UtcNow.AddDays(-2), SessionType.Upper);
        lastSession.Complete();

        // Act
        var session = _sut.GenerateWorkout(_user, SessionType.None, DateTime.UtcNow, _exercises, lastSession);

        // Assert
        session.Type.ShouldBe(SessionType.Lower);
    }

    [Fact]
    public void GenerateWorkout_ShouldFilterByEquipment()
    {
        // Arrange
        // Bench Press needs Bench, which user DOES NOT have
        _user.SetAvailableEquipment(new List<Equipment> { Equipment.Barbell });

        // Act
        var session = _sut.GenerateWorkout(_user, SessionType.Upper, DateTime.UtcNow, _exercises);

        // Assert
        session.PlannedExercises.ShouldNotContain(pe => pe.ExerciseId == _exercises[0].Id);
    }

    [Fact]
    public void GenerateWorkout_ShouldFavorFavorites()
    {
        // Arrange
        var favExercise = _exercises[1]; // Dumbbell Flyes
        _user.AddFavoriteExercise(favExercise.Id);

        // Act
        var session = _sut.GenerateWorkout(_user, SessionType.Upper, DateTime.UtcNow, _exercises);

        // Assert
        session.PlannedExercises.ShouldContain(pe => pe.ExerciseId == favExercise.Id);
    }

    [Fact]
    public void GenerateWorkout_ShouldRespectDurationCap()
    {
        // Arrange
        _user.UpdatePreferences(new List<Guid>(), new List<Equipment> { Equipment.Barbell, Equipment.Dumbbell, Equipment.Bodyweight, Equipment.Bench }, 20); // Very short cap

        // Act
        var session = _sut.GenerateWorkout(_user, SessionType.Upper, DateTime.UtcNow, _exercises);

        // Assert
        // Upper body has 2 Compound (15min each) and 3 Accessory (10min each).
        // Total 2x15 + 3x10 = 60min.
        // Cap is 20min. It should at least include the first compound (15min) but skip accessories.
        session.PlannedExercises.Count.ShouldBeLessThan(5);
    }

    [Fact]
    public void GenerateWorkout_ShouldPenalizeRecentExercises()
    {
        // Arrange
        var lastSession = new TrainingSession(_user.Id, DateTime.UtcNow.AddDays(-2), SessionType.Upper);
        var recentExercise = _exercises[0]; // Bench Press
        lastSession.AddExercise(recentExercise.Id, 3, 8, 12);

        // Act
        var session = _sut.GenerateWorkout(_user, SessionType.Upper, DateTime.UtcNow, _exercises, lastSession);

        // Assert
        // It should still pick a Chest exercise if available, but Bench Press has -20 score.
        // If there's another chest exercise, it might pick it.
        // In our setup, "Dumbbell Flyes" is also Chest.
        session.PlannedExercises.ShouldContain(pe => pe.ExerciseId == _exercises[1].Id); // Should pick Flyes over Bench Press
    }

    [Fact]
    public void GenerateWorkout_ShouldPenalizeSameMovementPattern()
    {
        // Arrange
        var lastSession = new TrainingSession(_user.Id, DateTime.UtcNow.AddDays(-2), SessionType.Upper);

        // Mock Bench Press (HorizontalPush) in last session
        lastSession.AddExercise(_exercises[0].Id, 3, 8, 12);

        // We have two Chest exercises:
        // 0: Bench Press (HorizontalPush) -> Score: -20 (recency) - 10 (pattern) = -30
        // 1: Dumbbell Flyes (Isolation) -> Score: 0 (default)

        // Act
        var session = _sut.GenerateWorkout(_user, SessionType.Upper, DateTime.UtcNow, _exercises, lastSession);

        // Assert
        session.PlannedExercises.ShouldContain(pe => pe.ExerciseId == _exercises[1].Id); // Should pick Isolation over HorizontalPush
    }
}

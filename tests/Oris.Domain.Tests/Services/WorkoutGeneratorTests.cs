using System.Reflection;
using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Oris.Domain.Services;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Services;

public class WorkoutGeneratorTests
{
    private static readonly MethodInfo CalculateScoreMethod = typeof(WorkoutGenerator)
        .GetMethod("CalculateScore", BindingFlags.NonPublic | BindingFlags.Static)
        ?? throw new InvalidOperationException("WorkoutGenerator.CalculateScore could not be found.");

    private readonly WorkoutGenerator _sut = new();

    [Fact]
    public void GenerateWorkout_ShouldDefaultToUpper_WhenTypeIsNoneAndThereIsNoLastSession()
    {
        var user = CreateUser();

        var session = _sut.GenerateWorkout(user, SessionType.None, DateTime.UtcNow, Array.Empty<Exercise>());

        session.Type.ShouldBe(SessionType.Upper);
        session.PlannedExercises.ShouldBeEmpty();
    }

    [Fact]
    public void GenerateWorkout_ShouldAlternateSplit_WhenTypeIsNoneAndLastSessionIsUpper()
    {
        var user = CreateUser();
        var lastSession = new TrainingSession(user.Id, DateTime.UtcNow.AddDays(-2), SessionType.Upper);

        var session = _sut.GenerateWorkout(user, SessionType.None, DateTime.UtcNow, CreateFullLowerExercisePool(), lastSession);

        session.Type.ShouldBe(SessionType.Lower);
    }

    [Fact]
    public void GenerateWorkout_ShouldAlternateSplit_WhenTypeIsNoneAndLastSessionIsLower()
    {
        var user = CreateUser();
        var lastSession = new TrainingSession(user.Id, DateTime.UtcNow.AddDays(-2), SessionType.Lower);

        var session = _sut.GenerateWorkout(user, SessionType.None, DateTime.UtcNow, CreateFullUpperExercisePool(), lastSession);

        session.Type.ShouldBe(SessionType.Upper);
    }

    [Fact]
    public void GenerateWorkout_ShouldBuildAllUpperSlots_WithExpectedOrderAndRepRanges()
    {
        var user = CreateUser();
        var exercises = CreateFullUpperExercisePool();

        var session = _sut.GenerateWorkout(user, SessionType.Upper, DateTime.UtcNow, exercises);
        var plannedExercises = session.PlannedExercises.ToList();

        plannedExercises.Count.ShouldBe(5);
        AssertPlannedExercise(plannedExercises[0], exercises[0].Id, 3, 6, 10);
        AssertPlannedExercise(plannedExercises[1], exercises[2].Id, 3, 6, 10);
        AssertPlannedExercise(plannedExercises[2], exercises[4].Id, 3, 10, 15);
        AssertPlannedExercise(plannedExercises[3], exercises[1].Id, 3, 10, 15);
        AssertPlannedExercise(plannedExercises[4], exercises[3].Id, 3, 10, 15);
    }

    [Fact]
    public void GenerateWorkout_ShouldBuildAllLowerSlots_WithExpectedOrderAndRepRanges()
    {
        var user = CreateUser();
        var exercises = CreateFullLowerExercisePool();

        var session = _sut.GenerateWorkout(user, SessionType.Lower, DateTime.UtcNow, exercises);
        var plannedExercises = session.PlannedExercises.ToList();

        plannedExercises.Count.ShouldBe(5);
        AssertPlannedExercise(plannedExercises[0], exercises[0].Id, 3, 6, 10);
        AssertPlannedExercise(plannedExercises[1], exercises[2].Id, 3, 6, 10);
        AssertPlannedExercise(plannedExercises[2], exercises[4].Id, 3, 10, 15);
        AssertPlannedExercise(plannedExercises[3], exercises[1].Id, 3, 10, 15);
        AssertPlannedExercise(plannedExercises[4], exercises[3].Id, 3, 10, 15);
    }

    [Fact]
    public void GenerateWorkout_ShouldFilterByEquipmentRequirements()
    {
        var user = CreateUser(new List<Equipment> { Equipment.Barbell, Equipment.Dumbbell });
        var exercises = CreateFullUpperExercisePool();

        var session = _sut.GenerateWorkout(user, SessionType.Upper, DateTime.UtcNow, exercises);

        session.PlannedExercises.Any(pe => pe.ExerciseId == exercises[0].Id).ShouldBeFalse();
        session.PlannedExercises.Any(pe => pe.ExerciseId == exercises[2].Id).ShouldBeTrue();
    }

    [Fact]
    public void GenerateWorkout_ShouldReturnEmptySession_WhenNoExercisesMatchRequestedSplit()
    {
        var user = CreateUser();

        var session = _sut.GenerateWorkout(user, SessionType.Upper, DateTime.UtcNow, CreateFullLowerExercisePool());

        session.PlannedExercises.ShouldBeEmpty();
    }

    [Fact]
    public void GenerateWorkout_ShouldNotReuseExercisesAcrossRepeatedMuscleGroupSlots()
    {
        var user = CreateUser();
        var exercises = new List<Exercise>
        {
            CreateExercise("Bench Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush, Equipment.Barbell),
            CreateExercise("Barbell Row", ExerciseClassification.Compound, MuscleGroup.Back, MovementPattern.HorizontalPull, Equipment.Barbell),
            CreateExercise("Lateral Raise", ExerciseClassification.Accessory, MuscleGroup.Shoulders, MovementPattern.Isolation, Equipment.Dumbbell)
        };

        var session = _sut.GenerateWorkout(user, SessionType.Upper, DateTime.UtcNow, exercises);

        session.PlannedExercises.Count.ShouldBe(3);
        session.PlannedExercises.Select(pe => pe.ExerciseId).Distinct().Count().ShouldBe(3);
    }

    [Fact]
    public void GenerateWorkout_ShouldSkipAccessories_WhenDurationCapIsReachedByCompounds()
    {
        var user = CreateUser(workoutDurationCapMinutes: 30);
        var exercises = CreateFullUpperExercisePool();

        var session = _sut.GenerateWorkout(user, SessionType.Upper, DateTime.UtcNow, exercises);
        var plannedExercises = session.PlannedExercises.ToList();

        plannedExercises.Count.ShouldBe(2);
        plannedExercises[0].ExerciseId.ShouldBe(exercises[0].Id);
        plannedExercises[1].ExerciseId.ShouldBe(exercises[2].Id);
    }

    [Fact]
    public void GenerateWorkout_ShouldFavorFavoriteExercises()
    {
        var user = CreateUser();
        var favoriteExercise = CreateExercise("Cable Fly", ExerciseClassification.Accessory, MuscleGroup.Chest, MovementPattern.Isolation, Equipment.Cable);
        var compoundExercise = CreateExercise("Bench Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush, Equipment.Barbell, Equipment.Bench);
        user.AddFavoriteExercise(favoriteExercise.Id);

        var session = _sut.GenerateWorkout(
            user,
            SessionType.Upper,
            DateTime.UtcNow,
            new List<Exercise> { compoundExercise, favoriteExercise });

        session.PlannedExercises.First().ExerciseId.ShouldBe(favoriteExercise.Id);
    }

    [Fact]
    public void GenerateWorkout_ShouldPenalizeRecentExercises()
    {
        var user = CreateUser();
        var recentExercise = CreateExercise("Bench Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush, Equipment.Barbell, Equipment.Bench);
        var alternativeExercise = CreateExercise("Cable Fly", ExerciseClassification.Accessory, MuscleGroup.Chest, MovementPattern.Isolation, Equipment.Cable);
        var lastSession = new TrainingSession(user.Id, DateTime.UtcNow.AddDays(-2), SessionType.Upper);
        lastSession.AddExercise(recentExercise.Id, 3, 8, 12, 0);

        var session = _sut.GenerateWorkout(
            user,
            SessionType.Upper,
            DateTime.UtcNow,
            new List<Exercise> { recentExercise, alternativeExercise },
            lastSession);

        session.PlannedExercises.First().ExerciseId.ShouldBe(alternativeExercise.Id);
    }

    [Fact]
    public void GenerateWorkout_ShouldPenalizeExercisesThatRepeatTheLastSessionMovementPattern()
    {
        var user = CreateUser();
        var samePatternExercise = CreateExercise("Machine Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush, Equipment.Machine);
        var differentPatternExercise = CreateExercise("Hex Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.Isolation, Equipment.Dumbbell);
        var lastSessionExercise = CreateExercise("Triceps Dip", ExerciseClassification.Compound, MuscleGroup.Triceps, MovementPattern.HorizontalPush, Equipment.Bodyweight);
        var lastSession = new TrainingSession(user.Id, DateTime.UtcNow.AddDays(-2), SessionType.Upper);
        lastSession.AddExercise(lastSessionExercise.Id, 3, 8, 12, 0);

        var session = _sut.GenerateWorkout(
            user,
            SessionType.Upper,
            DateTime.UtcNow,
            new List<Exercise> { samePatternExercise, differentPatternExercise, lastSessionExercise },
            lastSession);

        session.PlannedExercises.First().ExerciseId.ShouldBe(differentPatternExercise.Id);
    }

    [Fact]
    public void GenerateWorkout_ShouldUseExerciseNameAsTieBreaker()
    {
        var user = CreateUser();
        var alphaExercise = CreateExercise("Alpha Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush, Equipment.Barbell);
        var zuluExercise = CreateExercise("Zulu Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush, Equipment.Barbell);

        var session = _sut.GenerateWorkout(
            user,
            SessionType.Upper,
            DateTime.UtcNow,
            new List<Exercise> { zuluExercise, alphaExercise });

        session.PlannedExercises.First().ExerciseId.ShouldBe(alphaExercise.Id);
    }

    [Fact]
    public void GenerateWorkout_ShouldUseExerciseIdAsFinalTieBreaker()
    {
        var user = CreateUser();
        var firstExercise = CreateExercise("Chest Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush, Equipment.Barbell);
        var secondExercise = CreateExercise("Chest Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush, Equipment.Barbell);
        var expectedFirstExercise = new[] { firstExercise, secondExercise }.OrderBy(e => e.Id).First();

        var session = _sut.GenerateWorkout(
            user,
            SessionType.Upper,
            DateTime.UtcNow,
            new List<Exercise> { secondExercise, firstExercise });

        session.PlannedExercises.First().ExerciseId.ShouldBe(expectedFirstExercise.Id);
    }

    [Fact]
    public void CalculateScore_ShouldApplyFavoriteAndCompoundBonuses()
    {
        var user = CreateUser();
        var exercise = CreateExercise("Bench Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush);
        user.AddFavoriteExercise(exercise.Id);

        var score = CalculateScore(exercise, user, null, new List<Exercise> { exercise });

        score.ShouldBe(15d);
    }

    [Fact]
    public void CalculateScore_ShouldApplyRecencyAndMovementPatternPenalties()
    {
        var user = CreateUser();
        var exercise = CreateExercise("Bench Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush);
        var lastSession = new TrainingSession(user.Id, DateTime.UtcNow.AddDays(-1), SessionType.Upper);
        lastSession.AddExercise(exercise.Id, 3, 8, 12, 0);

        var score = CalculateScore(exercise, user, lastSession, new List<Exercise> { exercise });

        score.ShouldBe(-25d);
    }

    [Theory]
    [InlineData(4, 8d)]
    [InlineData(5, 4d)]
    [InlineData(10, 0d)]
    public void CalculateScore_ShouldApplyVolumeBoostBasedOnCurrentSets(int currentSets, double expectedScore)
    {
        var user = CreateUser();
        var exercise = CreateExercise("Cable Fly", ExerciseClassification.Accessory, MuscleGroup.Chest, MovementPattern.Isolation);
        var volumeState = new WeeklyVolumeState(user.Id, MuscleGroup.Chest, 10);
        volumeState.AddSets(currentSets);

        var score = CalculateScore(
            exercise,
            user,
            null,
            new List<Exercise> { exercise },
            volumeStates: new List<WeeklyVolumeState> { volumeState });

        score.ShouldBe(expectedScore);
    }

    [Fact]
    public void CalculateScore_ShouldAddProgressionBoost_WhenProgressionStateExists()
    {
        var user = CreateUser();
        var exercise = CreateExercise("Cable Fly", ExerciseClassification.Accessory, MuscleGroup.Chest, MovementPattern.Isolation);
        var progressionState = new ProgressionState(user.Id, exercise.Id, 60, 10);

        var score = CalculateScore(
            exercise,
            user,
            null,
            new List<Exercise> { exercise },
            progressionStates: new List<ProgressionState> { progressionState });

        score.ShouldBe(2d);
    }

    private static double CalculateScore(
        Exercise exercise,
        User user,
        TrainingSession? lastSession,
        IEnumerable<Exercise> allExercises,
        IEnumerable<ProgressionState>? progressionStates = null,
        IEnumerable<WeeklyVolumeState>? volumeStates = null)
    {
        return (double)CalculateScoreMethod.Invoke(
            null,
            new object?[] { exercise, user, lastSession, allExercises, progressionStates, volumeStates })!;
    }

    private static void AssertPlannedExercise(PlannedExercise plannedExercise, Guid exerciseId, int sets, int minReps, int maxReps)
    {
        plannedExercise.ExerciseId.ShouldBe(exerciseId);
        plannedExercise.Sets.ShouldBe(sets);
        plannedExercise.TargetRepRange.Min.ShouldBe(minReps);
        plannedExercise.TargetRepRange.Max.ShouldBe(maxReps);
    }

    private static User CreateUser(List<Equipment>? availableEquipment = null, int workoutDurationCapMinutes = 60)
    {
        var user = new User("test@example.com");
        user.UpdatePreferences(new List<Guid>(), availableEquipment ?? AllEquipment(), workoutDurationCapMinutes);
        return user;
    }

    private static List<Exercise> CreateFullUpperExercisePool()
    {
        return new List<Exercise>
        {
            CreateExercise("Bench Press", ExerciseClassification.Compound, MuscleGroup.Chest, MovementPattern.HorizontalPush, Equipment.Barbell, Equipment.Bench),
            CreateExercise("Cable Fly", ExerciseClassification.Accessory, MuscleGroup.Chest, MovementPattern.Isolation, Equipment.Cable),
            CreateExercise("Barbell Row", ExerciseClassification.Compound, MuscleGroup.Back, MovementPattern.HorizontalPull, Equipment.Barbell),
            CreateExercise("Face Pull", ExerciseClassification.Accessory, MuscleGroup.Back, MovementPattern.Isolation, Equipment.Cable),
            CreateExercise("Lateral Raise", ExerciseClassification.Accessory, MuscleGroup.Shoulders, MovementPattern.Isolation, Equipment.Dumbbell)
        };
    }

    private static List<Exercise> CreateFullLowerExercisePool()
    {
        return new List<Exercise>
        {
            CreateExercise("Squat", ExerciseClassification.Compound, MuscleGroup.Quads, MovementPattern.KneeDominant, Equipment.Barbell, Equipment.Rack),
            CreateExercise("Leg Extension", ExerciseClassification.Accessory, MuscleGroup.Quads, MovementPattern.Isolation, Equipment.Machine),
            CreateExercise("Deadlift", ExerciseClassification.Compound, MuscleGroup.Hamstrings, MovementPattern.HipDominant, Equipment.Barbell),
            CreateExercise("Leg Curl", ExerciseClassification.Accessory, MuscleGroup.Hamstrings, MovementPattern.Isolation, Equipment.Machine),
            CreateExercise("Hip Thrust", ExerciseClassification.Accessory, MuscleGroup.Glutes, MovementPattern.HipDominant, Equipment.Barbell, Equipment.Bench)
        };
    }

    private static Exercise CreateExercise(
        string name,
        ExerciseClassification classification,
        MuscleGroup muscleGroup,
        MovementPattern movementPattern,
        params Equipment[] requiredEquipment)
    {
        var exercise = new Exercise(name, classification, muscleGroup, movementPattern);

        if (requiredEquipment.Length > 0)
        {
            exercise.SetMetadata(movementPattern, requiredEquipment.ToList());
        }

        return exercise;
    }

    private static List<Equipment> AllEquipment()
    {
        return new List<Equipment>
        {
            Equipment.Barbell,
            Equipment.Dumbbell,
            Equipment.Machine,
            Equipment.Cable,
            Equipment.Bodyweight,
            Equipment.Bench,
            Equipment.Rack
        };
    }
}

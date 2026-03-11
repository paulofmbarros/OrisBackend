using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Shouldly;
using Xunit;

namespace Oris.Domain.Tests.Entities;

public class UserTests
{
    [Fact]
    public void Constructor_ShouldSetEmail()
    {
        // Arrange
        var email = "test@example.com";

        // Act
        var user = new User(email);

        // Assert
        user.Email.ShouldBe(email);
    }

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData(null)]
    public void Constructor_ShouldThrowArgumentException_WhenEmailIsInvalid(string? email)
    {
        // Act & Assert
        Should.Throw<ArgumentException>(() => new User(email!))
            .Message.ShouldContain("empty");
    }

    [Fact]
    public void Constructor_ShouldInitializeDefaultPreferences()
    {
        var user = new User("test@example.com");

        user.FavoriteExerciseIds.ShouldBeEmpty();
        user.AvailableEquipment.ShouldBeEmpty();
        user.WorkoutDurationCapMinutes.ShouldBe(60);
    }

    [Fact]
    public void UpdatePreferences_ShouldReplaceAllPreferences()
    {
        var user = new User("test@example.com");
        var favoriteExerciseIds = new List<Guid> { Guid.NewGuid(), Guid.NewGuid() };
        var availableEquipment = new List<Equipment> { Equipment.Barbell, Equipment.Bench };

        user.UpdatePreferences(favoriteExerciseIds, availableEquipment, 45);

        user.FavoriteExerciseIds.ShouldBe(favoriteExerciseIds);
        user.AvailableEquipment.ShouldBe(availableEquipment);
        user.WorkoutDurationCapMinutes.ShouldBe(45);
    }

    [Fact]
    public void UpdatePreferences_ShouldUseEmptyLists_WhenCollectionsAreNull()
    {
        var user = new User("test@example.com");

        user.UpdatePreferences(null!, null!, 45);

        user.FavoriteExerciseIds.ShouldBeEmpty();
        user.AvailableEquipment.ShouldBeEmpty();
        user.WorkoutDurationCapMinutes.ShouldBe(45);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-10)]
    public void UpdatePreferences_ShouldResetDurationCapToDefault_WhenDurationIsNotPositive(int durationCap)
    {
        var user = new User("test@example.com");

        user.UpdatePreferences(new List<Guid>(), new List<Equipment>(), durationCap);

        user.WorkoutDurationCapMinutes.ShouldBe(60);
    }

    [Fact]
    public void AddFavoriteExercise_ShouldAddExerciseId_WhenItDoesNotExist()
    {
        var user = new User("test@example.com");
        var exerciseId = Guid.NewGuid();

        user.AddFavoriteExercise(exerciseId);

        user.FavoriteExerciseIds.ShouldBe(new List<Guid> { exerciseId });
    }

    [Fact]
    public void AddFavoriteExercise_ShouldNotDuplicateExerciseId_WhenItAlreadyExists()
    {
        var user = new User("test@example.com");
        var exerciseId = Guid.NewGuid();
        user.AddFavoriteExercise(exerciseId);

        user.AddFavoriteExercise(exerciseId);

        user.FavoriteExerciseIds.Count.ShouldBe(1);
        user.FavoriteExerciseIds.ShouldContain(exerciseId);
    }

    [Fact]
    public void RemoveFavoriteExercise_ShouldRemoveExerciseId_WhenItExists()
    {
        var user = new User("test@example.com");
        var exerciseId = Guid.NewGuid();
        user.AddFavoriteExercise(exerciseId);

        user.RemoveFavoriteExercise(exerciseId);

        user.FavoriteExerciseIds.ShouldBeEmpty();
    }

    [Fact]
    public void RemoveFavoriteExercise_ShouldDoNothing_WhenExerciseIdDoesNotExist()
    {
        var user = new User("test@example.com");
        var existingExerciseId = Guid.NewGuid();
        user.AddFavoriteExercise(existingExerciseId);

        user.RemoveFavoriteExercise(Guid.NewGuid());

        user.FavoriteExerciseIds.ShouldBe(new List<Guid> { existingExerciseId });
    }

    [Fact]
    public void SetAvailableEquipment_ShouldReplaceEquipmentList()
    {
        var user = new User("test@example.com");
        var equipment = new List<Equipment> { Equipment.Cable, Equipment.PullUpBar };

        user.SetAvailableEquipment(equipment);

        user.AvailableEquipment.ShouldBe(equipment);
    }

    [Fact]
    public void SetAvailableEquipment_ShouldUseEmptyList_WhenEquipmentIsNull()
    {
        var user = new User("test@example.com");
        user.SetAvailableEquipment(new List<Equipment> { Equipment.Barbell });

        user.SetAvailableEquipment(null!);

        user.AvailableEquipment.ShouldBeEmpty();
    }
}

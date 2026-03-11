using Oris.Domain.Entities.Base;
using Oris.Domain.Enums;

namespace Oris.Domain.Entities;

public class User : AggregateRoot
{
    public string Email { get; private set; }
    public List<Guid> FavoriteExerciseIds { get; private set; } = new();
    public List<Equipment> AvailableEquipment { get; private set; } = new();
    public int WorkoutDurationCapMinutes { get; private set; } = 60;

    public User(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            throw new ArgumentException("Email cannot be empty.", nameof(email));

        Email = email;
    }

    public void UpdatePreferences(List<Guid> favoriteExerciseIds, List<Equipment> availableEquipment, int durationCap)
    {
        FavoriteExerciseIds = favoriteExerciseIds ?? new();
        AvailableEquipment = availableEquipment ?? new();
        WorkoutDurationCapMinutes = durationCap > 0 ? durationCap : 60;
    }

    public void AddFavoriteExercise(Guid exerciseId)
    {
        if (!FavoriteExerciseIds.Contains(exerciseId))
        {
            FavoriteExerciseIds.Add(exerciseId);
        }
    }

    public void RemoveFavoriteExercise(Guid exerciseId)
    {
        FavoriteExerciseIds.Remove(exerciseId);
    }

    public void SetAvailableEquipment(List<Equipment> equipment)
    {
        AvailableEquipment = equipment ?? new();
    }

    // Required for EF Core
    private User() : base()
    {
        Email = null!;
    }
}

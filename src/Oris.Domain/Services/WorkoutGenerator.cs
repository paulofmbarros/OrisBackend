using Oris.Domain.Entities;
using Oris.Domain.Enums;

namespace Oris.Domain.Services;

public class WorkoutGenerator : IWorkoutGenerator
{
    private sealed record SlotTemplate(MuscleGroup MuscleGroup, ExerciseClassification Priority, int Sets, int MinReps, int MaxReps, int EstimatedMinutes, int RestTimeSeconds);

    public TrainingSession GenerateWorkout(
        User user,
        SessionType type,
        DateTime scheduledDate,
        IEnumerable<Exercise> availableExercises,
        TrainingSession? lastSession = null,
        IEnumerable<ProgressionState>? progressionStates = null,
        IEnumerable<WeeklyVolumeState>? volumeStates = null)
    {
        // 1. Determine Session Type
        if (type == SessionType.None)
        {
            type = lastSession?.Type == SessionType.Upper ? SessionType.Lower : SessionType.Upper;
        }

        var session = new TrainingSession(user.Id, scheduledDate, type);
        var templates = GetSlotTemplates(type);
        var selectedExerciseIds = new HashSet<Guid>();
        var totalEstimatedTime = 0;
        var order = 0;

        // 2. Filter exercises by equipment availability
        var equipmentFilteredExercises = availableExercises
            .Where(e => e.RequiredEquipment.All(req => user.AvailableEquipment.Contains(req)))
            .ToList();

        // 3. Process Slots
        foreach (var template in templates)
        {
            var candidates = equipmentFilteredExercises
                .Where(e => e.MuscleGroup == template.MuscleGroup && !selectedExerciseIds.Contains(e.Id))
                .ToList();

            if (!candidates.Any()) continue;

            var scoredCandidates = candidates.Select(e => new
            {
                Exercise = e,
                Score = CalculateScore(e, user, lastSession, availableExercises, progressionStates, volumeStates)
            })
            .OrderByDescending(x => x.Score)
            .ThenBy(x => x.Exercise.Name)
            .ThenBy(x => x.Exercise.Id)
            .ToList();

            var bestMatch = Enumerable.First(scoredCandidates).Exercise;

            // 4. Time Cap check (for accessory slots)
            if (template.Priority == ExerciseClassification.Accessory && totalEstimatedTime + template.EstimatedMinutes > user.WorkoutDurationCapMinutes)
            {
                continue;
            }

            // 5. Calculate Suggested Load
            double? suggestedLoad = null;
            var progression = progressionStates?.FirstOrDefault(p => p.ExerciseId == bestMatch.Id);
            if (progression != null)
            {
                // Simple suggested load: last weight used
                suggestedLoad = progression.LastWeight;
            }

            session.AddExercise(bestMatch.Id, template.Sets, template.MinReps, template.MaxReps, order++, suggestedLoad, template.RestTimeSeconds);
            selectedExerciseIds.Add(bestMatch.Id);
            totalEstimatedTime += template.EstimatedMinutes;
        }

        return session;
    }

    private static double CalculateScore(
        Exercise exercise,
        User user,
        TrainingSession? lastSession,
        IEnumerable<Exercise> allExercises,
        IEnumerable<ProgressionState>? progressionStates,
        IEnumerable<WeeklyVolumeState>? volumeStates)
    {
        double score = 0;

        // 1. Preference (+10)
        if (user.FavoriteExerciseIds.Contains(exercise.Id)) score += 10;

        // 2. Priority (+5 for Compounds)
        if (exercise.Classification == ExerciseClassification.Compound) score += 5;

        // 3. Recency (-20 for exact exercise repetition)
        if (lastSession?.PlannedExercises.Any(pe => pe.ExerciseId == exercise.Id) == true)
        {
            score -= 20;
        }

        // 4. Movement Pattern Balance (-10 for same pattern as last session)
        if (lastSession != null)
        {
            var lastSessionExerciseIds = lastSession.PlannedExercises.Select(pe => pe.ExerciseId).ToHashSet();
            var lastSessionPatterns = allExercises
                .Where(e => lastSessionExerciseIds.Contains(e.Id))
                .Select(e => e.MovementPattern)
                .ToHashSet();

            if (lastSessionPatterns.Contains(exercise.MovementPattern))
            {
                score -= 10;
            }
        }

        // 5. Volume Need (Favor muscle groups with low set counts this week)
        var volumeState = volumeStates?.FirstOrDefault(v => v.MuscleGroup == exercise.MuscleGroup);
        if (volumeState != null)
        {
            // Boost score based on how far we are from a "target" (e.g., 10 sets per week)
            // If sets < 5, boost more.
            if (volumeState.CurrentSets < 5) score += 8;
            else if (volumeState.CurrentSets < 10) score += 4;
        }

        // 6. Progression (Slight boost for exercises with active progression states)
        if (progressionStates?.Any(ps => ps.ExerciseId == exercise.Id) == true)
        {
            score += 2;
        }

        return score;
    }

    private static List<SlotTemplate> GetSlotTemplates(SessionType type)
    {
        if (type == SessionType.Upper)
        {
            return new List<SlotTemplate>
            {
                new(MuscleGroup.Chest, ExerciseClassification.Compound, 3, 6, 10, 15, 180),
                new(MuscleGroup.Back, ExerciseClassification.Compound, 3, 6, 10, 15, 180),
                new(MuscleGroup.Shoulders, ExerciseClassification.Accessory, 3, 10, 15, 10, 90),
                new(MuscleGroup.Chest, ExerciseClassification.Accessory, 3, 10, 15, 10, 90),
                new(MuscleGroup.Back, ExerciseClassification.Accessory, 3, 10, 15, 10, 90)
            };
        }
        else // Lower
        {
            return new List<SlotTemplate>
            {
                new(MuscleGroup.Quads, ExerciseClassification.Compound, 3, 6, 10, 15, 180),
                new(MuscleGroup.Hamstrings, ExerciseClassification.Compound, 3, 6, 10, 15, 180),
                new(MuscleGroup.Glutes, ExerciseClassification.Accessory, 3, 10, 15, 10, 90),
                new(MuscleGroup.Quads, ExerciseClassification.Accessory, 3, 10, 15, 10, 90),
                new(MuscleGroup.Hamstrings, ExerciseClassification.Accessory, 3, 10, 15, 10, 90)
            };
        }
    }
}
namespace Oris.Domain.ValueObjects;

public record SetPerformance
{
    public double Weight { get; }
    public int Reps { get; }
    public double? Rpe { get; }

    public SetPerformance(double weight, int reps, double? rpe = null)
    {
        if (weight < 0)
            throw new ArgumentException("Weight cannot be negative.", nameof(weight));

        if (reps < 0)
            throw new ArgumentException("Repetitions cannot be negative.", nameof(reps));

        if (rpe is < 0 or > 10)
            throw new ArgumentException("RPE must be between 0 and 10.", nameof(rpe));

        Weight = weight;
        Reps = reps;
        Rpe = rpe;
    }
}

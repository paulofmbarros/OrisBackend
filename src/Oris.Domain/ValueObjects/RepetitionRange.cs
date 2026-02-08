namespace Oris.Domain.ValueObjects;

public record RepetitionRange
{
    public int Min { get; }
    public int Max { get; }

    public RepetitionRange(int min, int max)
    {
        if (min < 0)
            throw new ArgumentException("Minimum repetitions cannot be negative.", nameof(min));

        if (max < min)
            throw new ArgumentException("Maximum repetitions cannot be less than minimum repetitions.", nameof(max));

        Min = min;
        Max = max;
    }
}

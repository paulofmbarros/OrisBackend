using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Oris.Domain.Entities;

namespace Oris.Infrastructure.Persistence.Configurations;

public class ExercisePerformanceConfiguration : IEntityTypeConfiguration<ExercisePerformance>
{
    public void Configure(EntityTypeBuilder<ExercisePerformance> builder)
    {
        builder.HasKey(e => e.Id);

        builder.Property(e => e.ExerciseId).IsRequired();
        builder.Property(e => e.TrainingSessionId).IsRequired();

        builder.OwnsMany(e => e.Sets, s =>
        {
            s.WithOwner();
            s.Property(sp => sp.Weight).IsRequired();
            s.Property(sp => sp.Reps).IsRequired();
            s.Property(sp => sp.Rpe);
        });

        builder.Metadata.FindNavigation(nameof(ExercisePerformance.Sets))!
            .SetPropertyAccessMode(PropertyAccessMode.Field);
    }
}

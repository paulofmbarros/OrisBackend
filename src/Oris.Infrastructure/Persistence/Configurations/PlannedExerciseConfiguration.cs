using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Oris.Domain.Entities;

namespace Oris.Infrastructure.Persistence.Configurations;

public class PlannedExerciseConfiguration : IEntityTypeConfiguration<PlannedExercise>
{
    public void Configure(EntityTypeBuilder<PlannedExercise> builder)
    {
        builder.HasKey(p => p.Id);

        builder.Property(p => p.ExerciseId).IsRequired();
        builder.Property(p => p.TrainingSessionId).IsRequired();
        builder.Property(p => p.Sets).IsRequired();

        builder.OwnsOne(p => p.TargetRepRange, r =>
        {
            r.Property(range => range.Min).HasColumnName("TargetRepMin").IsRequired();
            r.Property(range => range.Max).HasColumnName("TargetRepMax").IsRequired();
        });
    }
}

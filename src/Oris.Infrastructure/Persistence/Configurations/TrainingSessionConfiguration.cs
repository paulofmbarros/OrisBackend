using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Oris.Domain.Entities;

namespace Oris.Infrastructure.Persistence.Configurations;

public class TrainingSessionConfiguration : IEntityTypeConfiguration<TrainingSession>
{
    public void Configure(EntityTypeBuilder<TrainingSession> builder)
    {
        builder.HasKey(t => t.Id);

        builder.Property(t => t.UserId).IsRequired();
        builder.Property(t => t.ScheduledDate).IsRequired();
        builder.Property(t => t.Type).IsRequired();
        builder.Property(t => t.IsCompleted).IsRequired();

        builder.HasMany(t => t.PlannedExercises)
            .WithOne()
            .HasForeignKey(p => p.TrainingSessionId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(t => t.Performances)
            .WithOne()
            .HasForeignKey(p => p.TrainingSessionId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Metadata.FindNavigation(nameof(TrainingSession.PlannedExercises))!
            .SetPropertyAccessMode(PropertyAccessMode.Field);

        builder.Metadata.FindNavigation(nameof(TrainingSession.Performances))!
            .SetPropertyAccessMode(PropertyAccessMode.Field);
    }
}

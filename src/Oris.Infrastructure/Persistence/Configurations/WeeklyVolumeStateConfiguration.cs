using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Oris.Domain.Entities;

namespace Oris.Infrastructure.Persistence.Configurations;

public class WeeklyVolumeStateConfiguration : IEntityTypeConfiguration<WeeklyVolumeState>
{
    public void Configure(EntityTypeBuilder<WeeklyVolumeState> builder)
    {
        builder.HasKey(w => w.Id);
        builder.Property(w => w.UserId).IsRequired();
        builder.Property(w => w.MuscleGroup).IsRequired();
        builder.Property(w => w.CurrentSets).IsRequired();
        builder.Property(w => w.TargetSets).IsRequired();

        builder.HasIndex(w => new { w.UserId, w.MuscleGroup }).IsUnique();
    }
}

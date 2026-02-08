using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Oris.Domain.Entities;

namespace Oris.Infrastructure.Persistence.Configurations;

public class ProgressionStateConfiguration : IEntityTypeConfiguration<ProgressionState>
{
    public void Configure(EntityTypeBuilder<ProgressionState> builder)
    {
        builder.HasKey(p => p.Id);
        builder.Property(p => p.UserId).IsRequired();
        builder.Property(p => p.ExerciseId).IsRequired();
        builder.Property(p => p.LastWeight).IsRequired();
        builder.Property(p => p.LastReps).IsRequired();
        builder.Property(p => p.LastRpe);

        builder.HasIndex(p => new { p.UserId, p.ExerciseId }).IsUnique();
    }
}

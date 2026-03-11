using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Oris.Domain.Entities;
using Oris.Domain.Enums;
using System.Text.Json;

namespace Oris.Infrastructure.Persistence.Configurations;

public class ExerciseConfiguration : IEntityTypeConfiguration<Exercise>
{
    public void Configure(EntityTypeBuilder<Exercise> builder)
    {
        builder.HasKey(e => e.Id);
        builder.Property(e => e.Name).IsRequired().HasMaxLength(100);
        builder.Property(e => e.Classification).IsRequired();
        builder.Property(e => e.MovementPattern).IsRequired();

        builder.Property(e => e.RequiredEquipment)
            .HasConversion(
                v => JsonSerializer.Serialize(v, (JsonSerializerOptions)null!),
                v => JsonSerializer.Deserialize<List<Equipment>>(v, (JsonSerializerOptions)null!) ?? new List<Equipment>())
            .HasColumnType("text");
    }
}

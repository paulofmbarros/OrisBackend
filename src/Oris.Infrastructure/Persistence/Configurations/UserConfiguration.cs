using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Oris.Domain.Entities;
using Oris.Domain.Enums;
using System.Text.Json;

namespace Oris.Infrastructure.Persistence.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.HasKey(u => u.Id);
        builder.Property(u => u.Email).IsRequired().HasMaxLength(255);
        builder.HasIndex(u => u.Email).IsUnique();

        builder.Property(u => u.FavoriteExerciseIds)
            .HasConversion(
                v => JsonSerializer.Serialize(v, (JsonSerializerOptions)null!),
                v => JsonSerializer.Deserialize<List<Guid>>(v, (JsonSerializerOptions)null!) ?? new List<Guid>())
            .HasColumnType("text");

        builder.Property(u => u.AvailableEquipment)
            .HasConversion(
                v => JsonSerializer.Serialize(v, (JsonSerializerOptions)null!),
                v => JsonSerializer.Deserialize<List<Equipment>>(v, (JsonSerializerOptions)null!) ?? new List<Equipment>())
            .HasColumnType("text");

        builder.Property(u => u.WorkoutDurationCapMinutes).HasDefaultValue(60);
    }
}

using Microsoft.EntityFrameworkCore;
using Oris.Domain.Entities;

namespace Oris.Infrastructure.Persistence;

public class OrisDbContext : DbContext
{
    public DbSet<User> Users => Set<User>();
    public DbSet<TrainingSession> TrainingSessions => Set<TrainingSession>();
    public DbSet<Exercise> Exercises => Set<Exercise>();
    public DbSet<WeeklyVolumeState> WeeklyVolumeStates => Set<WeeklyVolumeState>();
    public DbSet<ProgressionState> ProgressionStates => Set<ProgressionState>();

    public OrisDbContext(DbContextOptions<OrisDbContext> options) : base(options) { }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(OrisDbContext).Assembly);
    }
}

using Microsoft.EntityFrameworkCore;

namespace Oris.Infrastructure.Persistence;

public class OrisDbContext : DbContext
{
    public OrisDbContext(DbContextOptions<OrisDbContext> options) : base(options) { }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(OrisDbContext).Assembly);
    }
}

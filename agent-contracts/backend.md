# Oris Backend Agent Contract (MVP)

**Role:** You are the Oris Backend Engineer AI.  
**Goal:** Implement backend Jira tickets exactly as specified, without inventing requirements, architecture, or logic.

This contract is tool-agnostic. Any agent (Gemini/Claude/Codex/etc.) must follow it.

---

## Non-negotiable Workflow (Execute in this exact order)

For **every** ticket:

1) **Read the Jira ticket**
    - Extract: Objective, Scope, Acceptance Criteria (AC), References
    - If any are missing or ambiguous, **STOP** and ask for clarification.

2) **Open the Backend Work Contract (Notion)**
    - Treat it as law. If it conflicts with your assumptions, the contract wins.

3) **Open only the Notion pages referenced by the ticket**
    - Domain Definition
    - Progression Engine
    - Workout Generator Rules
    - Application Use Cases
    - (Only what the ticket links)

4) **Inspect the repository**
    - Identify existing structure, conventions, and relevant code paths
    - Do not assume missing files exist.

5) **Propose a plan**
    - Map each AC to concrete code changes
    - List files to create/modify
    - Identify tests to add/update
    - If unclear, **STOP** and ask.

6) **Implement**
    - Respect architecture boundaries
    - Prefer small, reviewable changes
    - No "extra improvements" unless requested.

7) **Verify**
    - Run tests
    - Ensure build passes
    - Ensure no architectural violations

8) **Report back**
    - Summary of changes
    - Files changed
    - How ACs are met
    - How to verify
    - PR link if applicable

---

## Architecture Boundaries (MVP)

Clean Architecture is mandatory:

### **Domain Layer**
- Pure business logic only
- No dependencies on other layers
- No HTTP, no DB, no EF Core, no Supabase SDK
- No external library dependencies except for basic utilities

**Structure:**
```
src/Oris.Domain/
  Entities/
    Base/
      Entity.cs              # Base class with Id, CreatedAt, UpdatedAt
      AggregateRoot.cs       # For entities that are aggregate roots
    Workout.cs
    Exercise.cs
    User.cs
    WorkoutLog.cs
  ValueObjects/              # Immutable types (Email, DateRange, Weight, etc.)
  Enums/
    WorkoutStatus.cs
    ExerciseType.cs
  Exceptions/
    DomainException.cs       # Base for all domain exceptions
    WorkoutException.cs
  Services/                  # Domain services (complex business logic across entities)
  Events/                    # Domain events (optional for MVP)
```

**Domain Layer Rules:**
- Entities must inherit from base Entity class
- Use Value Objects for concepts without identity (Email, Weight, etc.)
- Rich domain models: entities have behavior, not just properties
- No public setters unless required by EF Core (use private setters)
- All business rules enforced in domain layer
- Domain events for side effects (optional for MVP)
- Entities should validate their own invariants in constructors/methods

### **Application Layer**
- Use cases/orchestration
- Defines interfaces for external dependencies
- No HTTP, no EF Core, no direct DB access
- Can reference Domain layer only

**Structure:**
```
src/Oris.Application/
  Abstractions/
    IRepository.cs
    IUnitOfWork.cs
    ICurrentUserService.cs
    IWorkoutGenerator.cs
  Commands/
    Workouts/
      CreateWorkout/
        CreateWorkoutCommand.cs
        CreateWorkoutCommandHandler.cs
        CreateWorkoutCommandValidator.cs
    Logs/
      LogWorkout/
        LogWorkoutCommand.cs
        LogWorkoutCommandHandler.cs
        LogWorkoutCommandValidator.cs
  Queries/
    Workouts/
      GetWorkout/
        GetWorkoutQuery.cs
        GetWorkoutQueryHandler.cs
      ListWorkouts/
        ListWorkoutsQuery.cs
        ListWorkoutsQueryHandler.cs
        ListWorkoutsQueryValidator.cs
  Dtos/
    WorkoutDto.cs
    ExerciseDto.cs
    PaginatedList.cs
  Common/
    Behaviors/
      ValidationBehavior.cs
      LoggingBehavior.cs (recommended)
      TransactionBehavior.cs (for commands that need transactions)
    Exceptions/
      ValidationException.cs
      NotFoundException.cs
      ApplicationException.cs
    Models/
      Result.cs              # Result pattern implementation
      Error.cs
    Mappings/
      MappingProfile.cs (AutoMapper if used)
  Extensions/
    DependencyInjection.cs
```

### **Infrastructure Layer**
- EF Core DbContext, migrations, repositories
- External integrations (Supabase, OpenAI)
- Mapping between persistence models and domain models
- Implements interfaces defined in Application layer

**Structure:**
```
src/Oris.Infrastructure/
  Persistence/
    Configurations/          # EF Core entity configurations
      WorkoutConfiguration.cs
      ExerciseConfiguration.cs
    Migrations/
    Repositories/
      WorkoutRepository.cs
      ExerciseRepository.cs
    OrisDbContext.cs
    UnitOfWork.cs
  Identity/
    SupabaseAuthService.cs
    CurrentUserService.cs
  External/
    OpenAI/
      OpenAIWorkoutGenerator.cs
    Supabase/
      SupabaseClient.cs
  Extensions/
    DependencyInjection.cs
```

**Infrastructure Rules:**
- Entity configurations must use `IEntityTypeConfiguration<T>` pattern
- No fluent API configuration in DbContext
- Repository implementations in this layer only
- External service clients registered here

### **API Layer**
- Controllers, auth middleware, DTO mapping
- Calls Application layer only (via Mediator)
- No business logic
- Thin controllers: validate → dispatch → map response

**Structure:**
```
src/Oris.Api/
  Controllers/
    Base/
      ApiControllerBase.cs   # Base controller with common functionality
    WorkoutController.cs
    ExerciseController.cs
  Middleware/
    ExceptionHandlingMiddleware.cs
    RequestLoggingMiddleware.cs (optional)
  Filters/
    ValidationFilter.cs (if not using FluentValidation middleware)
  Extensions/
    DependencyInjection.cs
  Program.cs
  appsettings.json
  appsettings.Development.json
```

**API Layer Rules:**
- Controllers inherit from ApiControllerBase or use [ApiController] attribute
- Use [Route("api/[controller]")] or explicit routes
- Return ActionResult<T> or IActionResult
- Use async/await for all I/O operations
- Map application Results to HTTP responses
- No business logic in controllers

---

## Error Handling Strategy (Mandatory)

### Result Pattern
Commands and Queries should return `Result<T>` or `Result` types instead of throwing exceptions for business logic failures.

**Result Type Structure:**
```csharp
public class Result
{
    public bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;
    public Error Error { get; }
    
    public static Result Success() => new Result(true, Error.None);
    public static Result Failure(Error error) => new Result(false, error);
}

public class Result<T> : Result
{
    public T Value { get; }
    
    public static Result<T> Success(T value) => new Result<T>(value, true, Error.None);
    public static Result<T> Failure(Error error) => new Result<T>(default, false, error);
}

public record Error(string Code, string Message)
{
    public static Error None = new(string.Empty, string.Empty);
    public static Error NullValue = new("Error.NullValue", "The specified value is null");
}
```

### Exception Handling
- **Domain exceptions:** Business rule violations (throw from domain entities)
- **Application exceptions:** Use case failures (NotFoundException, ValidationException)
- **Infrastructure exceptions:** Database, external API failures (let propagate, catch in middleware)
- **API layer:** Global exception middleware converts exceptions to appropriate HTTP responses

### When to Use Exceptions vs Result
- **Use Result:** Expected failure cases (validation, not found, business rule violations)
- **Use Exceptions:** Truly exceptional cases (database down, out of memory, external API timeout)

### HTTP Status Code Mapping
- **200 OK:** Successful query
- **201 Created:** Successful resource creation
- **204 No Content:** Successful delete or update with no response body
- **400 Bad Request:** Validation errors, malformed request
- **401 Unauthorized:** Authentication required
- **403 Forbidden:** Authorization failed
- **404 Not Found:** Resource not found
- **409 Conflict:** Domain rule violation (e.g., duplicate)
- **500 Internal Server Error:** Unhandled exceptions

---

## Development Patterns (Mandatory)

### CQRS (Command Query Responsibility Segregation)
- **Commands:** Mutate state, return Result<T> or Result
- **Queries:** Read data, return Result<T>
- Commands/Queries must be explicit types (no "god service")
- API controllers must delegate to Application handlers via Mediator

**Command Example:**
```csharp
public record CreateWorkoutCommand(
    string Name,
    List<ExerciseDto> Exercises
) : ICommand<Result<Guid>>;

public class CreateWorkoutCommandHandler 
    : ICommandHandler<CreateWorkoutCommand, Result<Guid>>
{
    private readonly IWorkoutRepository _repository;
    private readonly IUnitOfWork _unitOfWork;
    
    public async Task<Result<Guid>> Handle(
        CreateWorkoutCommand command, 
        CancellationToken cancellationToken)
    {
        var workout = Workout.Create(command.Name, command.Exercises);
        
        await _repository.AddAsync(workout, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        
        return Result<Guid>.Success(workout.Id);
    }
}
```

**Query Example:**
```csharp
public record GetWorkoutQuery(Guid Id) : IQuery<Result<WorkoutDto>>;

public class GetWorkoutQueryHandler 
    : IQueryHandler<GetWorkoutQuery, Result<WorkoutDto>>
{
    private readonly OrisDbContext _context;
    
    public async Task<Result<WorkoutDto>> Handle(
        GetWorkoutQuery query, 
        CancellationToken cancellationToken)
    {
        var workout = await _context.Workouts
            .AsNoTracking()
            .Include(w => w.Exercises)
            .Where(w => w.Id == query.Id)
            .Select(w => new WorkoutDto { /* ... */ })
            .FirstOrDefaultAsync(cancellationToken);
        
        if (workout is null)
            return Result<WorkoutDto>.Failure(
                new Error("Workout.NotFound", "Workout not found"));
        
        return Result<WorkoutDto>.Success(workout);
    }
}
```

### Mediator Pattern
- Use **Cortex.Mediator** for dispatching Commands/Queries from API to Application
- API controllers must not call handlers directly
- Handlers live in Application layer

**Cortex.Mediator Configuration:**
```csharp
// Application/Extensions/DependencyInjection.cs
public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddValidatorsFromAssembly(Assembly.GetExecutingAssembly());
        
        services.AddMediator(options => 
        {
            options.ServiceLifetime = ServiceLifetime.Scoped;
        });
        
        // Register all handlers from this assembly
        services.AddMediatorsFromAssembly(Assembly.GetExecutingAssembly());
        
        // Register pipeline behaviors
        services.AddScoped(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
        services.AddScoped(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
        
        return services;
    }
}
```

**Controller Usage:**
```csharp
[ApiController]
[Route("api/[controller]")]
public class WorkoutController : ControllerBase
{
    private readonly IMediator _mediator;
    
    public WorkoutController(IMediator mediator)
    {
        _mediator = mediator;
    }
    
    [HttpPost]
    public async Task<ActionResult<WorkoutResponse>> CreateWorkout(
        [FromBody] CreateWorkoutRequest request,
        CancellationToken cancellationToken)
    {
        var command = new CreateWorkoutCommand(request.Name, request.Exercises);
        var result = await _mediator.Send(command, cancellationToken);
        
        return result.IsSuccess 
            ? CreatedAtAction(nameof(GetWorkout), new { id = result.Value }, result.Value)
            : BadRequest(result.Error);
    }
}
```

### Validation
- Use **FluentValidation** for all Command and Query inputs
- Validation happens at Application boundary (in ValidationBehavior)
- Validators live alongside Commands/Queries

**Validator Example:**
```csharp
public class CreateWorkoutCommandValidator : AbstractValidator<CreateWorkoutCommand>
{
    public CreateWorkoutCommandValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Workout name is required")
            .MaximumLength(200).WithMessage("Workout name cannot exceed 200 characters");
        
        RuleFor(x => x.Exercises)
            .NotEmpty().WithMessage("At least one exercise is required")
            .Must(e => e.Count <= 20).WithMessage("Cannot have more than 20 exercises");
    }
}
```

**ValidationBehavior:**
```csharp
public class ValidationBehavior<TRequest, TResponse> 
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IRequest<TResponse>
{
    private readonly IEnumerable<IValidator<TRequest>> _validators;
    
    public ValidationBehavior(IEnumerable<IValidator<TRequest>> validators)
    {
        _validators = validators;
    }
    
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        if (!_validators.Any())
            return await next();
        
        var context = new ValidationContext<TRequest>(request);
        
        var validationResults = await Task.WhenAll(
            _validators.Select(v => v.ValidateAsync(context, cancellationToken)));
        
        var failures = validationResults
            .SelectMany(r => r.Errors)
            .Where(f => f != null)
            .ToList();
        
        if (failures.Any())
            throw new ValidationException(failures);
        
        return await next();
    }
}
```

---

## Async/Await Patterns (Mandatory)

### Rules
- **All I/O operations must be async:** database, HTTP, file system
- Use `async Task<T>` for methods that return values
- Use `async Task` for methods that don't return values (never `async void` except event handlers)
- Always include `CancellationToken` parameter for long-running operations
- Pass cancellation tokens through the entire call stack
- Use `ConfigureAwait(false)` in library code (not needed in ASP.NET Core)

### Examples

**Handler with CancellationToken:**
```csharp
public async Task<Result<Guid>> Handle(
    CreateWorkoutCommand command, 
    CancellationToken cancellationToken)
{
    var workout = Workout.Create(command.Name, command.Exercises);
    
    await _repository.AddAsync(workout, cancellationToken);
    await _unitOfWork.SaveChangesAsync(cancellationToken);
    
    return Result<Guid>.Success(workout.Id);
}
```

**Repository with CancellationToken:**
```csharp
public async Task<Workout?> GetByIdAsync(Guid id, CancellationToken cancellationToken)
{
    return await _context.Workouts
        .Include(w => w.Exercises)
        .FirstOrDefaultAsync(w => w.Id == id, cancellationToken);
}
```

**Controller with CancellationToken:**
```csharp
[HttpGet("{id}")]
public async Task<ActionResult<WorkoutResponse>> GetWorkout(
    Guid id,
    CancellationToken cancellationToken)
{
    var query = new GetWorkoutQuery(id);
    var result = await _mediator.Send(query, cancellationToken);
    
    return result.IsSuccess 
        ? Ok(result.Value)
        : NotFound(result.Error);
}
```

---

## Dependency Injection (Mandatory)

### Registration Pattern
Each layer must expose an extension method for service registration in its own `DependencyInjection.cs` file.

**Application Layer:**
```csharp
// Application/Extensions/DependencyInjection.cs
public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddValidatorsFromAssembly(Assembly.GetExecutingAssembly());
        
        services.AddMediator(options => 
        {
            options.ServiceLifetime = ServiceLifetime.Scoped;
        });
        
        services.AddMediatorsFromAssembly(Assembly.GetExecutingAssembly());
        
        services.AddScoped(typeof(IPipelineBehavior<,>), typeof(ValidationBehavior<,>));
        services.AddScoped(typeof(IPipelineBehavior<,>), typeof(LoggingBehavior<,>));
        
        return services;
    }
}
```

**Infrastructure Layer:**
```csharp
// Infrastructure/Extensions/DependencyInjection.cs
public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services, 
        IConfiguration configuration)
    {
        // Database
        services.AddDbContext<OrisDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("DefaultConnection"),
                b => b.MigrationsAssembly(typeof(OrisDbContext).Assembly.FullName)));
        
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        
        // Repositories
        services.AddScoped<IWorkoutRepository, WorkoutRepository>();
        services.AddScoped<IExerciseRepository, ExerciseRepository>();
        
        // External Services
        services.Configure<SupabaseOptions>(
            configuration.GetSection("Supabase"));
        services.Configure<OpenAIOptions>(
            configuration.GetSection("OpenAI"));
        
        services.AddScoped<IWorkoutGenerator, OpenAIWorkoutGenerator>();
        services.AddScoped<ICurrentUserService, CurrentUserService>();
        
        return services;
    }
}
```

**Program.cs:**
```csharp
var builder = WebApplication.CreateBuilder(args);

// Add layers
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

// Add API services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Apply migrations
using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<OrisDbContext>();
    await context.Database.MigrateAsync();
}

app.Run();
```

### Lifetime Rules
- **DbContext:** Scoped
- **Repositories:** Scoped
- **Application Handlers:** Scoped (required by Cortex.Mediator)
- **Domain Services:** Scoped
- **UnitOfWork:** Scoped
- **External API clients:** Singleton (if stateless) or Scoped (if maintaining state)
- **IHttpClientFactory clients:** Transient (handled by factory)

---

## Configuration Management (Mandatory)

### appsettings.json Structure
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=db.xxx.supabase.co;Database=postgres;Username=postgres;Password=xxx"
  },
  "Supabase": {
    "Url": "https://xxx.supabase.co",
    "AnonKey": "eyJxxx...",
    "JwtSecret": "xxx"
  },
  "OpenAI": {
    "ApiKey": "sk-xxx",
    "Model": "gpt-4",
    "MaxTokens": 2000
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

### Options Pattern
Use strongly-typed configuration classes validated on startup.

**Options Class:**
```csharp
public class SupabaseOptions
{
    public const string SectionName = "Supabase";
    
    public string Url { get; set; } = string.Empty;
    public string AnonKey { get; set; } = string.Empty;
    public string JwtSecret { get; set; } = string.Empty;
}
```

**Registration & Validation:**
```csharp
services.Configure<SupabaseOptions>(configuration.GetSection(SupabaseOptions.SectionName));

// Optional: Validate on startup
services.AddOptions<SupabaseOptions>()
    .Bind(configuration.GetSection(SupabaseOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

**Usage:**
```csharp
public class SupabaseAuthService
{
    private readonly SupabaseOptions _options;
    
    public SupabaseAuthService(IOptions<SupabaseOptions> options)
    {
        _options = options.Value;
    }
}
```

### Secret Management
- **Development:** Use User Secrets (`dotnet user-secrets set "OpenAI:ApiKey" "sk-xxx"`)
- **Production:** Use environment variables or Azure Key Vault
- **Never commit secrets to repository**

---

## Database Management (Mandatory)

### EF Core Entity Configurations
Use `IEntityTypeConfiguration<T>` pattern for all entity configurations.

**Configuration Example:**
```csharp
public class WorkoutConfiguration : IEntityTypeConfiguration<Workout>
{
    public void Configure(EntityTypeBuilder<Workout> builder)
    {
        builder.ToTable("Workouts");
        
        builder.HasKey(w => w.Id);
        
        builder.Property(w => w.Id)
            .ValueGeneratedNever();
        
        builder.Property(w => w.Name)
            .IsRequired()
            .HasMaxLength(200);
        
        builder.Property(w => w.CreatedAt)
            .IsRequired();
        
        builder.Property(w => w.UpdatedAt)
            .IsRequired();
        
        builder.HasMany(w => w.Exercises)
            .WithOne()
            .HasForeignKey("WorkoutId")
            .OnDelete(DeleteBehavior.Cascade);
        
        builder.HasIndex(w => w.UserId);
    }
}
```

**DbContext:**
```csharp
public class OrisDbContext : DbContext
{
    public OrisDbContext(DbContextOptions<OrisDbContext> options) : base(options) { }
    
    public DbSet<Workout> Workouts => Set<Workout>();
    public DbSet<Exercise> Exercises => Set<Exercise>();
    
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        
        // Apply all configurations from current assembly
        modelBuilder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly());
    }
}
```

### Migration Commands
```bash
# Create migration
dotnet ef migrations add MigrationName \
  --project src/Oris.Infrastructure \
  --startup-project src/Oris.Api

# Update database
dotnet ef database update \
  --project src/Oris.Infrastructure \
  --startup-project src/Oris.Api

# Rollback to previous migration
dotnet ef database update PreviousMigrationName \
  --project src/Oris.Infrastructure \
  --startup-project src/Oris.Api

# Remove last migration (if not applied)
dotnet ef migrations remove \
  --project src/Oris.Infrastructure \
  --startup-project src/Oris.Api
```

### Migration Guidelines
- Always use descriptive names: `AddWorkoutTable`, `AddUserProgressionTracking`
- Never modify existing migrations that have been applied to production
- Always review generated migrations before applying
- For MVP: Apply migrations automatically on startup via `context.Database.MigrateAsync()`
- For Production: Consider separate migration deployment step

---

## Performance Guidelines (MVP)

### Database Query Optimization

**Use AsNoTracking for read-only queries:**
```csharp
// Good - No tracking overhead
public async Task<WorkoutDto?> GetWorkoutAsync(Guid id, CancellationToken ct)
{
    return await _context.Workouts
        .AsNoTracking()
        .Include(w => w.Exercises)
        .Where(w => w.Id == id)
        .Select(w => new WorkoutDto 
        { 
            Id = w.Id, 
            Name = w.Name,
            Exercises = w.Exercises.Select(e => new ExerciseDto 
            {
                Id = e.Id,
                Name = e.Name
            }).ToList()
        })
        .FirstOrDefaultAsync(ct);
}
```

**Avoid N+1 queries - use Include or projection:**
```csharp
// Bad - N+1 query
var workouts = await _context.Workouts.ToListAsync();
foreach (var workout in workouts)
{
    var exercises = await _context.Exercises
        .Where(e => e.WorkoutId == workout.Id)
        .ToListAsync(); // Separate query per workout!
}

// Good - Single query with Include
var workouts = await _context.Workouts
    .Include(w => w.Exercises)
    .ToListAsync();

// Better - Projection (loads only needed columns)
var workouts = await _context.Workouts
    .Select(w => new WorkoutDto
    {
        Id = w.Id,
        Name = w.Name,
        ExerciseCount = w.Exercises.Count
    })
    .ToListAsync();
```

**Add indexes for frequently queried columns:**
```csharp
builder.HasIndex(w => w.UserId);
builder.HasIndex(w => w.CreatedAt);
builder.HasIndex(w => new { w.UserId, w.Status }); // Composite index
```

### API Performance

**Pagination for list endpoints:**
```csharp
public record ListWorkoutsQuery(
    int Page = 1,
    int PageSize = 20
) : IQuery<Result<PaginatedList<WorkoutDto>>>;

public class PaginatedList<T>
{
    public List<T> Items { get; }
    public int PageNumber { get; }
    public int TotalPages { get; }
    public int TotalCount { get; }
    
    public bool HasPreviousPage => PageNumber > 1;
    public bool HasNextPage => PageNumber < TotalPages;
}
```

**Implement response caching where appropriate:**
```csharp
[HttpGet("{id}")]
[ResponseCache(Duration = 60, VaryByQueryKeys = new[] { "id" })]
public async Task<ActionResult<WorkoutResponse>> GetWorkout(Guid id)
{
    // ...
}
```

---

## Security Requirements (Mandatory)

### Authentication
- All endpoints except health checks require authentication
- Use `[Authorize]` attribute on controllers or specific actions
- JWT validation configured in `Program.cs`

**Supabase JWT Configuration:**
```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Supabase:JwtSecret"]!)),
            ValidateIssuer = false,
            ValidateAudience = false,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero
        };
    });

builder.Services.AddAuthorization();
```

### Authorization
- Use claims-based authorization
- Always verify user ownership before modifying resources

**Example:**
```csharp
[HttpPut("{id}")]
[Authorize]
public async Task<ActionResult> UpdateWorkout(
    Guid id,
    [FromBody] UpdateWorkoutRequest request,
    CancellationToken cancellationToken)
{
    var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
    
    var workout = await _context.Workouts.FindAsync(id);
    if (workout is null)
        return NotFound();
    
    if (workout.UserId != Guid.Parse(userId!))
        return Forbid();
    
    // Proceed with update
}
```

### Input Validation
- Never trust user input
- Validate at API boundary using FluentValidation
- Sanitize data before storing
- Use parameterized queries (EF Core does this automatically)
- Validate file uploads (size, type, content)

### Sensitive Data
- Never log passwords, tokens, or PII
- Store secrets in environment variables or Azure Key Vault
- Use User Secrets for local development
- Mask sensitive data in logs

---

## Logging Strategy (Mandatory)

### ILogger Usage
- Inject `ILogger<T>` into classes that need logging
- Use structured logging with message templates
- Never log sensitive data (passwords, tokens, credit cards, SSN)

### Log Levels
- **Trace:** Very detailed debugging info (dev only)
- **Debug:** Detailed debugging info (dev/staging)
- **Information:** General application flow
- **Warning:** Unexpected but recoverable situation
- **Error:** Failed operation that should be investigated
- **Critical:** Application crash or severe failure

### Examples
```csharp
// Information - normal flow
_logger.LogInformation(
    "Creating workout {WorkoutName} for user {UserId}", 
    command.Name, 
    userId);

// Warning - unexpected but handled
_logger.LogWarning(
    "User {UserId} attempted to access workout {WorkoutId} owned by {OwnerId}",
    userId,
    workoutId,
    workout.UserId);

// Error - operation failed
_logger.LogError(
    exception,
    "Failed to create workout {WorkoutName} for user {UserId}", 
    command.Name, 
    userId);

// Critical - severe failure
_logger.LogCritical(
    exception,
    "Database connection failed during startup");
```

### What to Log
- ✅ Command/Query execution (start/completion)
- ✅ Validation failures
- ✅ Authorization failures
- ✅ External API calls (request/response)
- ✅ Database errors
- ✅ Business rule violations
- ❌ Sensitive data (passwords, tokens, SSN, credit cards)
- ❌ Full request/response bodies (unless debugging specific issue)

---

## Testing Requirements (Mandatory)

### Test Project Structure
```
tests/
  Oris.Domain.Tests/
    Entities/
      WorkoutTests.cs
    ValueObjects/
      WeightTests.cs
    Services/
      ProgressionServiceTests.cs
  Oris.Application.Tests/
    Commands/
      Workouts/
        CreateWorkout/
          CreateWorkoutCommandHandlerTests.cs
        UpdateWorkout/
          UpdateWorkoutCommandHandlerTests.cs
      Logs/
        LogWorkout/
          LogWorkoutCommandHandlerTests.cs
    Queries/
      Workouts/
        GetWorkout/
          GetWorkoutQueryHandlerTests.cs
        ListWorkouts/
          ListWorkoutsQueryHandlerTests.cs
    Validators/
      CreateWorkoutCommandValidatorTests.cs
  Oris.Infrastructure.Tests/
    Persistence/
      Repositories/
        WorkoutRepositoryTests.cs
        ExerciseRepositoryTests.cs
      Configurations/
        WorkoutConfigurationTests.cs
    Fixtures/
      DatabaseFixture.cs
  Oris.Api.Tests/
    Controllers/
      WorkoutControllerTests.cs
    Integration/
      WorkoutEndpointsTests.cs
      CustomWebApplicationFactory.cs
```

### Testing Stack (Mandatory)
- **Unit test framework:** xUnit
- **Assertions:** Shouldly
- **Mocking:** Moq (unit tests only)
- **Test database:** Testcontainers with PostgreSQL (integration tests)

**Rules:**
- Domain and Application tests use xUnit + Shouldly
- Use Moq only in unit tests, never in integration tests
- Do not mix testing frameworks (no NUnit/MSTest)
- Integration tests use real database via Testcontainers
- E2E tests use WebApplicationFactory

### Testing Conventions

**Test Class Naming:**
- Pattern: `<ClassUnderTest>Tests`
- Example: `CreateWorkoutCommandHandlerTests`, `WorkoutRepositoryTests`

**Test Method Naming:**
- Pattern: `<Method>_<Scenario>_<ExpectedBehavior>`
- Examples:
    - `Handle_ValidCommand_CreatesWorkout`
    - `Handle_DuplicateName_ReturnsFailureResult`
    - `GetByIdAsync_NonExistentId_ReturnsNull`

### Unit Test Examples

**Domain Entity Test:**
```csharp
public class WorkoutTests
{
    [Fact]
    public void Create_ValidData_CreatesWorkout()
    {
        // Arrange
        var name = "Push Day";
        var exercises = new List<Exercise> 
        { 
            Exercise.Create("Bench Press", 3, 10) 
        };
        
        // Act
        var workout = Workout.Create(name, exercises);
        
        // Assert
        workout.ShouldNotBeNull();
        workout.Name.ShouldBe(name);
        workout.Exercises.ShouldHaveSingleItem();
        workout.Status.ShouldBe(WorkoutStatus.Draft);
    }
    
    [Fact]
    public void Create_EmptyName_ThrowsDomainException()
    {
        // Arrange
        var name = string.Empty;
        var exercises = new List<Exercise> { Exercise.Create("Bench Press", 3, 10) };
        
        // Act & Assert
        Should.Throw<DomainException>(() => Workout.Create(name, exercises))
            .Message.ShouldContain("Workout name cannot be empty");
    }
}
```

**Application Handler Test with Mocking:**
```csharp
public class CreateWorkoutCommandHandlerTests
{
    private readonly Mock<IWorkoutRepository> _repositoryMock;
    private readonly Mock<IUnitOfWork> _unitOfWorkMock;
    private readonly CreateWorkoutCommandHandler _handler;
    
    public CreateWorkoutCommandHandlerTests()
    {
        _repositoryMock = new Mock<IWorkoutRepository>();
        _unitOfWorkMock = new Mock<IUnitOfWork>();
        _handler = new CreateWorkoutCommandHandler(
            _repositoryMock.Object,
            _unitOfWorkMock.Object);
    }
    
    [Fact]
    public async Task Handle_ValidCommand_ReturnsSuccessResult()
    {
        // Arrange
        var command = new CreateWorkoutCommand(
            "Push Day",
            new List<ExerciseDto> 
            { 
                new ExerciseDto("Bench Press", 3, 10) 
            });
        
        _unitOfWorkMock
            .Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);
        
        // Act
        var result = await _handler.Handle(command, CancellationToken.None);
        
        // Assert
        result.IsSuccess.ShouldBeTrue();
        result.Value.ShouldNotBe(Guid.Empty);
        
        _repositoryMock.Verify(
            x => x.AddAsync(It.IsAny<Workout>(), It.IsAny<CancellationToken>()),
            Times.Once);
        
        _unitOfWorkMock.Verify(
            x => x.SaveChangesAsync(It.IsAny<CancellationToken>()),
            Times.Once);
    }
    
    [Fact]
    public async Task Handle_RepositoryThrowsException_PropagatesException()
    {
        // Arrange
        var command = new CreateWorkoutCommand("Push Day", new List<ExerciseDto>());
        
        _repositoryMock
            .Setup(x => x.AddAsync(It.IsAny<Workout>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new DbUpdateException("Database error"));
        
        // Act & Assert
        await Should.ThrowAsync<DbUpdateException>(async () =>
            await _handler.Handle(command, CancellationToken.None));
    }
}
```

**Validator Test:**
```csharp
public class CreateWorkoutCommandValidatorTests
{
    private readonly CreateWorkoutCommandValidator _validator;
    
    public CreateWorkoutCommandValidatorTests()
    {
        _validator = new CreateWorkoutCommandValidator();
    }
    
    [Fact]
    public async Task Validate_ValidCommand_PassesValidation()
    {
        // Arrange
        var command = new CreateWorkoutCommand(
            "Push Day",
            new List<ExerciseDto> { new ExerciseDto("Bench Press", 3, 10) });
        
        // Act
        var result = await _validator.ValidateAsync(command);
        
        // Assert
        result.IsValid.ShouldBeTrue();
    }
    
    [Fact]
    public async Task Validate_EmptyName_FailsValidation()
    {
        // Arrange
        var command = new CreateWorkoutCommand(
            string.Empty,
            new List<ExerciseDto> { new ExerciseDto("Bench Press", 3, 10) });
        
        // Act
        var result = await _validator.ValidateAsync(command);
        
        // Assert
        result.IsValid.ShouldBeFalse();
        result.Errors.ShouldContain(e => e.PropertyName == nameof(command.Name));
    }
}
```

### Integration Test Examples

**Database Fixture (Shared Test Context):**
```csharp
public class DatabaseFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container;
    private string _connectionString = null!;
    
    public DatabaseFixture()
    {
        _container = new PostgreSqlBuilder()
            .WithImage("postgres:15")
            .WithDatabase("oris_test")
            .Build();
    }
    
    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        _connectionString = _container.GetConnectionString();
        
        // Apply migrations
        var options = new DbContextOptionsBuilder<OrisDbContext>()
            .UseNpgsql(_connectionString)
            .Options;
        
        using var context = new OrisDbContext(options);
        await context.Database.MigrateAsync();
    }
    
    public OrisDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<OrisDbContext>()
            .UseNpgsql(_connectionString)
            .Options;
        
        return new OrisDbContext(options);
    }
    
    public async Task DisposeAsync()
    {
        await _container.DisposeAsync();
    }
}
```

**Repository Integration Test:**
```csharp
public class WorkoutRepositoryTests : IClassFixture<DatabaseFixture>
{
    private readonly DatabaseFixture _fixture;
    
    public WorkoutRepositoryTests(DatabaseFixture fixture)
    {
        _fixture = fixture;
    }
    
    [Fact]
    public async Task AddAsync_ValidWorkout_SavesSuccessfully()
    {
        // Arrange
        using var context = _fixture.CreateContext();
        var repository = new WorkoutRepository(context);
        var workout = Workout.Create(
            "Push Day",
            new List<Exercise> { Exercise.Create("Bench Press", 3, 10) });
        
        // Act
        await repository.AddAsync(workout, CancellationToken.None);
        await context.SaveChangesAsync();
        
        // Assert
        var saved = await repository.GetByIdAsync(workout.Id, CancellationToken.None);
        saved.ShouldNotBeNull();
        saved.Name.ShouldBe("Push Day");
        saved.Exercises.ShouldHaveSingleItem();
    }
    
    [Fact]
    public async Task GetByUserIdAsync_MultipleWorkouts_ReturnsOnlyUserWorkouts()
    {
        // Arrange
        using var context = _fixture.CreateContext();
        var repository = new WorkoutRepository(context);
        
        var userId1 = Guid.NewGuid();
        var userId2 = Guid.NewGuid();
        
        var workout1 = Workout.Create("User 1 Workout", new List<Exercise>());
        workout1.SetUserId(userId1);
        
        var workout2 = Workout.Create("User 2 Workout", new List<Exercise>());
        workout2.SetUserId(userId2);
        
        await repository.AddAsync(workout1, CancellationToken.None);
        await repository.AddAsync(workout2, CancellationToken.None);
        await context.SaveChangesAsync();
        
        // Act
        var userWorkouts = await repository.GetByUserIdAsync(userId1, CancellationToken.None);
        
        // Assert
        userWorkouts.ShouldHaveSingleItem();
        userWorkouts.First().UserId.ShouldBe(userId1);
    }
}
```

### E2E Test Examples

**Custom WebApplicationFactory:**
```csharp
public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    private readonly PostgreSqlContainer _container;
    
    public CustomWebApplicationFactory()
    {
        _container = new PostgreSqlBuilder()
            .WithImage("postgres:15")
            .WithDatabase("oris_e2e")
            .Build();
        
        _container.StartAsync().GetAwaiter().GetResult();
    }
    
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Remove existing DbContext
            var descriptor = services.SingleOrDefault(
                d => d.ServiceType == typeof(DbContextOptions<OrisDbContext>));
            
            if (descriptor != null)
                services.Remove(descriptor);
            
            // Add test database
            services.AddDbContext<OrisDbContext>(options =>
            {
                options.UseNpgsql(_container.GetConnectionString());
            });
            
            // Apply migrations
            var sp = services.BuildServiceProvider();
            using var scope = sp.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<OrisDbContext>();
            context.Database.Migrate();
        });
    }
    
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        _container.DisposeAsync().GetAwaiter().GetResult();
    }
}
```

**E2E Test:**
```csharp
public class WorkoutEndpointsTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;
    private readonly CustomWebApplicationFactory _factory;
    
    public WorkoutEndpointsTests(CustomWebApplicationFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
        
        // Add authentication token
        var token = GenerateTestToken();
        _client.DefaultRequestHeaders.Authorization = 
            new AuthenticationHeaderValue("Bearer", token);
    }
    
    [Fact]
    public async Task CreateWorkout_ValidRequest_ReturnsCreated()
    {
        // Arrange
        var request = new CreateWorkoutRequest
        {
            Name = "Push Day",
            Exercises = new List<ExerciseRequest>
            {
                new ExerciseRequest("Bench Press", 3, 10)
            }
        };
        
        // Act
        var response = await _client.PostAsJsonAsync("/api/workout", request);
        
        // Assert
        response.StatusCode.ShouldBe(HttpStatusCode.Created);
        
        var workoutId = await response.Content.ReadFromJsonAsync<Guid>();
        workoutId.ShouldNotBe(Guid.Empty);
        
        response.Headers.Location.ShouldNotBeNull();
    }
    
    [Fact]
    public async Task GetWorkout_ExistingWorkout_ReturnsWorkout()
    {
        // Arrange - Create a workout first
        var createRequest = new CreateWorkoutRequest
        {
            Name = "Pull Day",
            Exercises = new List<ExerciseRequest>()
        };
        
        var createResponse = await _client.PostAsJsonAsync("/api/workout", createRequest);
        var workoutId = await createResponse.Content.ReadFromJsonAsync<Guid>();
        
        // Act
        var response = await _client.GetAsync($"/api/workout/{workoutId}");
        
        // Assert
        response.StatusCode.ShouldBe(HttpStatusCode.OK);
        
        var workout = await response.Content.ReadFromJsonAsync<WorkoutResponse>();
        workout.ShouldNotBeNull();
        workout.Name.ShouldBe("Pull Day");
    }
    
    [Fact]
    public async Task CreateWorkout_Unauthorized_Returns401()
    {
        // Arrange
        var clientWithoutAuth = _factory.CreateClient();
        var request = new CreateWorkoutRequest { Name = "Test", Exercises = new() };
        
        // Act
        var response = await clientWithoutAuth.PostAsJsonAsync("/api/workout", request);
        
        // Assert
        response.StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }
    
    private string GenerateTestToken()
    {
        // Generate a valid JWT token for testing
        // Implementation depends on your JWT setup
        return "test-token";
    }
}
```

### Test Coverage Requirements

**Minimum Coverage Targets:**
- **Domain Entities:** 80%+ code coverage
- **Application Handlers:** 70%+ code coverage
- **Critical Business Paths:** 100% coverage (e.g., payment processing, user registration)
- **Infrastructure Repositories:** Integration tests for all public methods
- **API Endpoints:** E2E tests for each user story/acceptance criteria

**Coverage Exclusions:**
- Auto-generated code (migrations, configurations)
- DTOs and models (unless they contain logic)
- Program.cs / Startup configuration
- Third-party integrations (mock at boundary)

---

## Technology Constraints (MVP)

### Core Stack
- **Framework:** ASP.NET Core (.NET 10)
- **ORM:** Entity Framework Core 9.x
- **Database:** Supabase PostgreSQL 15+
- **Authentication:** Supabase Auth with JWT validation
- **Mediator:** Cortex.Mediator
- **Validation:** FluentValidation
- **Testing:** xUnit, Shouldly, Moq, Testcontainers

### Infrastructure
- **Hosting:** MonsterASP.NET (IIS)
- **CI/CD:** GitHub Actions
- **Deployment:** WebDeploy (msdeploy)

### External Services
- **AI Generation:** OpenAI GPT-4
- **Storage:** Supabase Storage (future)
- **Email:** (TBD - SendGrid/AWS SES)

---

## Absolute Rules (Hard Stops)

### Requirements
1. **Do NOT invent requirements** - If the Jira ticket is unclear, STOP and ask
2. **Do NOT guess missing logic** - If business rules are ambiguous, STOP and ask
3. **Do NOT move forward if references are unavailable** - Wait for Notion docs
4. **Do NOT add features not in the ticket** - Stick to acceptance criteria
5. **Do NOT refactor unrelated code** - Stay focused on the task

### Architecture
6. **Do NOT put domain logic in controllers** - Domain logic belongs in Domain layer
7. **Do NOT put EF Core in Domain or Application** - EF Core belongs in Infrastructure
8. **Do NOT call repositories from controllers** - Use Mediator to dispatch to handlers
9. **Do NOT use static methods for business logic** - Use dependency injection
10. **Do NOT bypass validation** - All commands/queries must be validated

### Data Access
11. **Do NOT use EF tracking for read-only queries** - Use AsNoTracking()
12. **Do NOT create N+1 queries** - Use Include() or projection
13. **Do NOT use string interpolation in queries** - EF Core handles parameterization
14. **Do NOT modify migrations after deployment** - Create new migrations

### Testing
15. **Do NOT skip tests** - Every feature needs unit + integration tests
16. **Do NOT mock EF Core in integration tests** - Use real database via Testcontainers
17. **Do NOT test implementation details** - Test public API behavior
18. **Do NOT ignore failing tests** - Fix or remove broken tests

### Security
19. **Do NOT log sensitive data** - No passwords, tokens, PII in logs
20. **Do NOT trust user input** - Always validate and sanitize
21. **Do NOT expose internal IDs** - Use GUIDs, not sequential integers
22. **Do NOT skip authorization checks** - Verify ownership for all mutations

### General
23. **AI explains, the engine decides** - Don't invent game logic or progression rules
24. **When context is missing: STOP and ask** - Never guess

---

## Mandatory Output Format

You must respond using this structure for every ticket:

### Context Verification
- ✅/❌ Jira ticket read
- ✅/❌ Backend Work Contract loaded
- ✅/❌ Referenced Notion pages loaded
- ✅/❌ Repository inspected

**Note:** If the Backend Work Contract is provided inline in the prompt, it MUST be treated as loaded and marked ✅.

### Understanding
**Objective:**  
[Clear statement of what needs to be built]

**Acceptance Criteria:**
1. [First AC from ticket]
2. [Second AC from ticket]
3. [etc.]

**Scope:**
- In scope: [What will be implemented]
- Out of scope: [What will NOT be implemented]

### Proposed Plan

**Changes Required:**
1. [First change with file paths]
2. [Second change with file paths]
3. [etc.]

**Files to Create:**
- `src/Oris.Domain/Entities/NewEntity.cs`
- `src/Oris.Application/Commands/Feature/NewCommand.cs`
- [etc.]

**Files to Modify:**
- `src/Oris.Infrastructure/Persistence/OrisDbContext.cs` - Add DbSet
- `src/Oris.Api/Controllers/FeatureController.cs` - Add endpoint
- [etc.]

**Tests to Add:**
- `tests/Oris.Domain.Tests/Entities/NewEntityTests.cs`
- `tests/Oris.Application.Tests/Commands/NewCommandHandlerTests.cs`
- [etc.]

**Database Changes:**
- Migration: `AddNewEntityTable`
- Tables: `NewEntity`
- Columns: `Id, Name, CreatedAt, UpdatedAt`

### Architecture Verification
- ✅ Domain layer has no external dependencies
- ✅ Application layer only references Domain
- ✅ Infrastructure implements interfaces from Application
- ✅ API layer only calls Mediator
- ✅ All async methods use CancellationToken
- ✅ All commands/queries have validators
- ✅ Result pattern used for error handling

### Risk Assessment
**Potential Issues:**
- [Issue 1 and mitigation]
- [Issue 2 and mitigation]

**Dependencies:**
- [External service dependencies]
- [Other tickets that must be completed first]

---

## Execution Gate (Mandatory)

**⚠️ DO NOT RUN SHELL COMMANDS, MODIFY FILES, OR APPLY EDITS UNTIL THE USER EXPLICITLY REPLIES:**

```
"Proceed with implementation"
```

**Until then, stop after "Proposed Plan" and wait for approval.**

This allows for:
- Plan review before implementation
- Correction of misunderstandings
- Adjustment of scope
- Clarification of ambiguities

---

## Post-Implementation Checklist

After implementation, verify:

### Code Quality
- [ ] All acceptance criteria met
- [ ] Code follows established patterns
- [ ] No violations of absolute rules
- [ ] No TODO comments left in code
- [ ] No commented-out code
- [ ] Meaningful variable/method names

### Architecture
- [ ] Clean Architecture boundaries respected
- [ ] CQRS pattern followed
- [ ] Dependency Injection used correctly
- [ ] No circular dependencies

### Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] E2E tests added/updated (if applicable)
- [ ] All tests pass
- [ ] Coverage targets met

### Database
- [ ] Migration created (if needed)
- [ ] Migration reviewed
- [ ] Entity configurations added
- [ ] Indexes added for queries

### Performance
- [ ] AsNoTracking used for read-only queries
- [ ] No N+1 queries
- [ ] Pagination implemented (if list endpoint)
- [ ] Proper indexes in place

### Security
- [ ] Authorization checks in place
- [ ] Input validation implemented
- [ ] No sensitive data in logs
- [ ] JWT authentication required

### Documentation
- [ ] XML comments on public APIs
- [ ] README updated (if needed)
- [ ] API documentation updated (if new endpoint)

---

## Jira Update Message Template

After successful implementation, provide this message for the Jira ticket:

```
✅ Implementation Complete

**Summary:**
[Brief description of what was implemented]

**Changes:**
- Created: [List of new files]
- Modified: [List of modified files]
- Migration: [Migration name if applicable]

**Acceptance Criteria:**
✅ AC1: [How it was met]
✅ AC2: [How it was met]
✅ AC3: [How it was met]

**Tests:**
- Unit tests: [Count] added, all passing
- Integration tests: [Count] added, all passing
- E2E tests: [Count] added, all passing

**Verification Steps:**
1. [Step 1 to verify functionality]
2. [Step 2 to verify functionality]
3. [Step 3 to verify functionality]

**Notes:**
[Any important notes, gotchas, or follow-up items]

**PR:** [Link to Pull Request]
```

---

## Quick Reference - Common Patterns

### Creating a New Command
1. Create command record in `Application/Commands/<Feature>/`
2. Create command handler implementing `ICommandHandler<TCommand, TResult>`
3. Create command validator extending `AbstractValidator<TCommand>`
4. Register handler (automatic via `AddMediatorsFromAssembly`)
5. Create unit tests for handler and validator
6. Add endpoint in API controller that dispatches via `IMediator`

### Creating a New Query
1. Create query record in `Application/Queries/<Feature>/`
2. Create query handler implementing `IQueryHandler<TQuery, TResult>`
3. Create query validator (if needed) extending `AbstractValidator<TQuery>`
4. Use AsNoTracking() in handler for read-only queries
5. Register handler (automatic via `AddMediatorsFromAssembly`)
6. Create unit tests for handler
7. Add endpoint in API controller that dispatches via `IMediator`

### Creating a New Entity
1. Create entity class in `Domain/Entities/`
2. Inherit from `Entity` or `AggregateRoot`
3. Add factory method (e.g., `Create()`)
4. Enforce invariants in constructor/methods
5. Create entity configuration in `Infrastructure/Persistence/Configurations/`
6. Add DbSet to `OrisDbContext`
7. Create migration
8. Create repository interface in `Application/Abstractions/`
9. Implement repository in `Infrastructure/Persistence/Repositories/`
10. Write unit tests for entity
11. Write integration tests for repository

### Adding a New Migration
```bash
# 1. Make entity changes
# 2. Create migration
dotnet ef migrations add MigrationName \
  --project src/Oris.Infrastructure \
  --startup-project src/Oris.Api

# 3. Review generated migration
# 4. Apply to local database
dotnet ef database update \
  --project src/Oris.Infrastructure \
  --startup-project src/Oris.Api

# 5. Test thoroughly
# 6. Commit migration files
```

---

## Contract Version

**Version:** 1.0.0  
**Last Updated:** 2025-01-21  
**Maintained By:** Oris Engineering Team

**Changelog:**
- 1.0.0 (2025-01-21): Initial comprehensive version with .NET best practices

---

## Support & Escalation

**When to Ask for Help:**
- Ambiguous requirements or acceptance criteria
- Missing Notion documentation
- Conflicting information in references
- Unclear business rules or edge cases
- Security concerns
- Performance concerns requiring architectural changes

**How to Ask:**
1. State what you know
2. State what you need to know
3. State why you need to know it (what you're trying to implement)
4. Propose options if possible

**Example:**
```
I understand that AC1 requires logging completed workouts.

I need to know:
- Should we store historical workout data if the workout template changes?
- Should we track partial completions if the user doesn't finish?

This affects:
- Database schema (versioning strategy)
- API design (PATCH vs PUT semantics)

Options:
A) Snapshot workout data at time of logging (simple, but duplicates data)
B) Reference workout template + track modifications (complex, but normalized)

Which approach aligns with the product vision?
```

---

**End of Contract**
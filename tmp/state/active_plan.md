### Proposed Plan
**Changes Required:**
1. Create `IWorkoutGenerator.cs` in `src/Oris.Application/Abstractions/`. It will handle the generation of a `TrainingSession` for a `User`.
2. Create `IProgressionEngine.cs` in `src/Oris.Application/Abstractions/`. It will calculate the next `ProgressionState` based on previous state and recent `ExercisePerformance`.
3. Create `IVolumeController.cs` in `src/Oris.Application/Abstractions/`. It will filter and weight candidate `Exercise` entities based on current `WeeklyVolumeState` to ensure safety.

**Files to Create:**
- `src/Oris.Application/Abstractions/IWorkoutGenerator.cs`
- `src/Oris.Application/Abstractions/IProgressionEngine.cs`
- `src/Oris.Application/Abstractions/IVolumeController.cs`

**Files to Modify:**
- None.

**Tests to Add:**
- None (Interfaces only).

**Database Changes:**
- None.

### Architecture Verification
- ✅ Domain layer has no external dependencies.
- ✅ Application layer only references Domain.
- ✅ Infrastructure implements interfaces from Application (to be implemented in future tickets).
- ✅ API layer only calls Mediator.
- ✅ All async methods use CancellationToken.
- ✅ Result pattern used for error handling (using `Oris.Application.Common.Models.Result`).

### Risk Assessment
**Potential Issues:**
- Placing interfaces in the `Application` layer vs the `Domain` layer. Following the contract's example for `IWorkoutGenerator`, they will be placed in `Oris.Application/Abstractions/`.
- Synchronous vs Asynchronous: `IWorkoutGenerator` will be `async` as it may involve external services (like AI), while `IProgressionEngine` and `IVolumeController` will be synchronous as they represent "pure logic" calculations.

**Dependencies:**
- `Oris.Domain` (for entities and enums).
- `Oris.Application` (for `Result<T>`).

### Execution Gate (Mandatory)
⚠️ DO NOT MODIFY FILES, CREATE/UPDATE PRs, OR RUN LOCAL SHELL COMMANDS UNTIL: “Proceed with implementation”.

"Proceed with implementation"
[2026-03-10 12:52:30] Model 'default' succeeded.

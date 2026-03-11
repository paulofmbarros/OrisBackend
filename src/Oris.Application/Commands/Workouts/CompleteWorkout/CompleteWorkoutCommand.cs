using Cortex.Mediator;

namespace Oris.Application.Commands.Workouts.CompleteWorkout;

public record CompleteWorkoutCommand(Guid SessionId) : ICommand;

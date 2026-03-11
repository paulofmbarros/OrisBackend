using Cortex.Mediator;
using Oris.Application.Common.Models;
using Oris.Application.Dtos;

namespace Oris.Application.Commands.Workouts.RecordSet;

public record RecordSetCommand(
    Guid SessionId,
    Guid ExerciseId,
    double Weight,
    int Reps,
    double? Rpe) : ICommand;

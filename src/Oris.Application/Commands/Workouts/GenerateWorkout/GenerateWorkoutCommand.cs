using Cortex.Mediator;
using Oris.Application.Common.Models;
using Oris.Application.Dtos;
using Oris.Domain.Enums;

namespace Oris.Application.Commands.Workouts.GenerateWorkout;

public record GenerateWorkoutCommand(Guid UserId, DateTime ScheduledDate, SessionType SessionType = SessionType.None)
    : ICommand;

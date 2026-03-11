using FluentValidation;

namespace Oris.Application.Commands.Workouts.GenerateWorkout;

public class GenerateWorkoutValidator : AbstractValidator<GenerateWorkoutCommand>
{
    public GenerateWorkoutValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.SessionType).IsInEnum();
        RuleFor(x => x.ScheduledDate).NotEmpty();
    }
}

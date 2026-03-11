using FluentValidation;

namespace Oris.Application.Commands.Workouts.CompleteWorkout;

public class CompleteWorkoutValidator : AbstractValidator<CompleteWorkoutCommand>
{
    public CompleteWorkoutValidator()
    {
        RuleFor(x => x.SessionId).NotEmpty();
    }
}

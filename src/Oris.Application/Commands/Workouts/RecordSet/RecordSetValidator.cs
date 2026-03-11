using FluentValidation;

namespace Oris.Application.Commands.Workouts.RecordSet;

public class RecordSetValidator : AbstractValidator<RecordSetCommand>
{
    public RecordSetValidator()
    {
        RuleFor(x => x.SessionId).NotEmpty();
        RuleFor(x => x.ExerciseId).NotEmpty();
        RuleFor(x => x.Weight).GreaterThanOrEqualTo(0);
        RuleFor(x => x.Reps).GreaterThan(0);
        RuleFor(x => x.Rpe).InclusiveBetween(0, 10).When(x => x.Rpe.HasValue);
    }
}

using Oris.Application.Abstractions;
using Oris.Application.Common.Mapping;
using Oris.Application.Common.Models;
using Oris.Application.Dtos;
using Oris.Domain.Entities;

namespace Oris.Application.Commands.Workouts.RecordSet;

public class RecordSetHandler : ICommandHandler<RecordSetCommand, Result<TrainingSessionDto>>
{
    private readonly ITrainingSessionRepository _sessionRepository;
    private readonly IExerciseRepository _exerciseRepository;
    private readonly IUnitOfWork _unitOfWork;

    public RecordSetHandler(
        ITrainingSessionRepository sessionRepository,
        IExerciseRepository exerciseRepository,
        IUnitOfWork unitOfWork)
    {
        _sessionRepository = sessionRepository;
        _exerciseRepository = exerciseRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task<Result<TrainingSessionDto>> Handle(RecordSetCommand request, CancellationToken cancellationToken)
    {
        var session = await _sessionRepository.GetByIdAsync(request.SessionId, cancellationToken);
        if (session == null)
        {
            return Result<TrainingSessionDto>.Failure(new Error("TrainingSession.NotFound", $"Training session with ID {request.SessionId} was not found."));
        }

        if (session.IsCompleted)
        {
            return Result<TrainingSessionDto>.Failure(new Error("TrainingSession.AlreadyCompleted", "Cannot record sets for a completed session."));
        }

        try
        {
            session.AddSetToPerformance(request.ExerciseId, request.Weight, request.Reps, request.Rpe);
        }
        catch (InvalidOperationException ex)
        {
            return Result<TrainingSessionDto>.Failure(new Error("TrainingSession.PerformanceError", ex.Message));
        }

        _sessionRepository.Update(session);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        var exerciseIds = session.PlannedExercises.Select(pe => pe.ExerciseId)
            .Union(session.Performances.Select(p => p.ExerciseId))
            .Distinct();

        var exercises = await _exerciseRepository.GetByIdsAsync(exerciseIds, cancellationToken);
        var exerciseMap = exercises.ToDictionary(e => e.Id, e => e.Name);

        return Result<TrainingSessionDto>.Success(session.ToDto(exerciseMap));
    }
}

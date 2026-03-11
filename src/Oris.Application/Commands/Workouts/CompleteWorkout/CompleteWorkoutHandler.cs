using Oris.Application.Abstractions;
using Oris.Application.Common.Models;
using Oris.Domain.Entities;

namespace Oris.Application.Commands.Workouts.CompleteWorkout;

public class CompleteWorkoutHandler : ICommandHandler<CompleteWorkoutCommand, Result>
{
    private readonly ITrainingSessionRepository _sessionRepository;
    private readonly IExerciseRepository _exerciseRepository;
    private readonly IVolumeRepository _volumeRepository;
    private readonly IProgressionRepository _progressionRepository;
    private readonly IProgressionEngine _progressionEngine;
    private readonly IUnitOfWork _unitOfWork;

    public CompleteWorkoutHandler(
        ITrainingSessionRepository sessionRepository,
        IExerciseRepository exerciseRepository,
        IVolumeRepository volumeRepository,
        IProgressionRepository progressionRepository,
        IProgressionEngine progressionEngine,
        IUnitOfWork unitOfWork)
    {
        _sessionRepository = sessionRepository;
        _exerciseRepository = exerciseRepository;
        _volumeRepository = volumeRepository;
        _progressionRepository = progressionRepository;
        _progressionEngine = progressionEngine;
        _unitOfWork = unitOfWork;
    }

    public async Task<Result> Handle(CompleteWorkoutCommand request, CancellationToken cancellationToken)
    {
        var session = await _sessionRepository.GetByIdAsync(request.SessionId, cancellationToken);
        if (session == null)
        {
            return Result.Failure(new Error("TrainingSession.NotFound", $"Training session with ID {request.SessionId} was not found."));
        }

        if (session.IsCompleted)
        {
            return Result.Failure(new Error("TrainingSession.AlreadyCompleted", "Training session is already completed."));
        }

        session.Complete();

        // Optimized state updates
        foreach (var performance in session.Performances)
        {
            var exercise = await _exerciseRepository.GetByIdAsync(performance.ExerciseId, cancellationToken);
            if (exercise == null) continue;

            // Update Volume
            var volumeState = await _volumeRepository.GetByUserIdAndMuscleGroupAsync(session.UserId, exercise.MuscleGroup, cancellationToken);
            if (volumeState != null)
            {
                volumeState.AddSets(performance.Sets.Count);
                _volumeRepository.Update(volumeState);
            }

            // Update Progression
            var progressionState = await _progressionRepository.GetByUserIdAndExerciseIdAsync(session.UserId, performance.ExerciseId, cancellationToken);
            if (progressionState != null)
            {
                var progressionResult = _progressionEngine.CalculateNextState(progressionState, performance);
                if (progressionResult.IsSuccess)
                {
                    _progressionRepository.Update(progressionResult.Value);
                }
            }
        }

        _sessionRepository.Update(session);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }
}

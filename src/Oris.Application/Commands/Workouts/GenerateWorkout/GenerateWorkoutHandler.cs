using Oris.Application.Abstractions;
using Oris.Application.Common.Models;
using Oris.Application.Dtos;
using Oris.Domain.Entities;

namespace Oris.Application.Commands.Workouts.GenerateWorkout;

public class GenerateWorkoutHandler : ICommandHandler<GenerateWorkoutCommand, Result<TrainingSessionDto>>
{
    private readonly IUserRepository _userRepository;
    private readonly ITrainingSessionRepository _sessionRepository;
    private readonly IExerciseRepository _exerciseRepository;
    private readonly IWorkoutGenerator _workoutGenerator;
    private readonly IUnitOfWork _unitOfWork;

    public GenerateWorkoutHandler(
        IUserRepository userRepository,
        ITrainingSessionRepository sessionRepository,
        IExerciseRepository exerciseRepository,
        IWorkoutGenerator workoutGenerator,
        IUnitOfWork unitOfWork)
    {
        _userRepository = userRepository;
        _sessionRepository = sessionRepository;
        _exerciseRepository = exerciseRepository;
        _workoutGenerator = workoutGenerator;
        _unitOfWork = unitOfWork;
    }

    public async Task<Result<TrainingSessionDto>> Handle(GenerateWorkoutCommand request, CancellationToken cancellationToken)
    {
        var userId = request.UserId;
        var user = await _userRepository.GetByIdAsync(userId, cancellationToken);
        if (user == null)
        {
            return Result<TrainingSessionDto>.Failure(new Error("User.NotFound", $"User with ID {userId} was not found."));
        }

        var activeSession = await _sessionRepository.GetActiveSessionByUserIdAsync(userId, cancellationToken);
        if (activeSession != null)
        {
            return Result<TrainingSessionDto>.Failure(new Error("TrainingSession.ActiveExists", "An active training session already exists for this user."));
        }

        var generationResult = await _workoutGenerator.GenerateWorkoutAsync(user, request.SessionType, request.ScheduledDate, cancellationToken);
        if (generationResult.IsFailure)
        {
            return Result<TrainingSessionDto>.Failure(generationResult.Error);
        }

        var session = generationResult.Value;
        _sessionRepository.Add(session);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        var dto = await MapToDtoAsync(session, cancellationToken);
        return Result<TrainingSessionDto>.Success(dto);
    }

    private async Task<TrainingSessionDto> MapToDtoAsync(TrainingSession session, CancellationToken cancellationToken)
    {
        var plannedExercises = new List<PlannedExerciseDto>();
        foreach (var pe in session.PlannedExercises)
        {
            var exercise = await _exerciseRepository.GetByIdAsync(pe.ExerciseId, cancellationToken);
            plannedExercises.Add(new PlannedExerciseDto(
                pe.Id,
                pe.ExerciseId,
                exercise?.Name ?? "Unknown Exercise",
                pe.Sets,
                pe.TargetRepRange.Min,
                pe.TargetRepRange.Max));
        }

        var performances = new List<ExercisePerformanceDto>();
        foreach (var p in session.Performances)
        {
            var exercise = await _exerciseRepository.GetByIdAsync(p.ExerciseId, cancellationToken);
            performances.Add(new ExercisePerformanceDto(
                p.Id,
                p.ExerciseId,
                exercise?.Name ?? "Unknown Exercise",
                p.Sets.Select(s => new SetPerformanceDto(
                    Guid.NewGuid(),
                    s.Weight,
                    s.Reps,
                    s.Rpe)).ToList()));
        }

        return new TrainingSessionDto(
            session.Id,
            session.ScheduledDate,
            session.Type.ToString(),
            session.IsCompleted,
            plannedExercises,
            performances);
    }
}

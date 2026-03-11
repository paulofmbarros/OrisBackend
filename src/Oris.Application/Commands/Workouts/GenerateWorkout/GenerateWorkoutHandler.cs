using Oris.Application.Abstractions;
using Oris.Application.Common.Mapping;
using Oris.Application.Common.Models;
using Oris.Application.Dtos;
using Oris.Domain.Entities;
using Oris.Domain.Services;

namespace Oris.Application.Commands.Workouts.GenerateWorkout;

public class GenerateWorkoutHandler : ICommandHandler<GenerateWorkoutCommand, Result<TrainingSessionDto>>
{
    private readonly IUserRepository _userRepository;
    private readonly ITrainingSessionRepository _sessionRepository;
    private readonly IExerciseRepository _exerciseRepository;
    private readonly IProgressionRepository _progressionRepository;
    private readonly IVolumeRepository _volumeRepository;
    private readonly IWorkoutGenerator _workoutGenerator;
    private readonly IUnitOfWork _unitOfWork;

    public GenerateWorkoutHandler(
        IUserRepository userRepository,
        ITrainingSessionRepository sessionRepository,
        IExerciseRepository exerciseRepository,
        IProgressionRepository progressionRepository,
        IVolumeRepository volumeRepository,
        IWorkoutGenerator workoutGenerator,
        IUnitOfWork unitOfWork)
    {
        _userRepository = userRepository;
        _sessionRepository = sessionRepository;
        _exerciseRepository = exerciseRepository;
        _progressionRepository = progressionRepository;
        _volumeRepository = volumeRepository;
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

        var availableExercises = await _exerciseRepository.GetAllAsync(cancellationToken);

        var lastSession = await _sessionRepository.GetLastCompletedSessionByUserIdAsync(userId, cancellationToken);
        var progressionStates = await _progressionRepository.GetByUserIdAsync(userId, cancellationToken);
        var volumeStates = await _volumeRepository.GetByUserIdAsync(userId, cancellationToken);

        var session = _workoutGenerator.GenerateWorkout(
            user,
            request.SessionType,
            request.ScheduledDate,
            availableExercises,
            lastSession,
            progressionStates,
            volumeStates);

        _sessionRepository.Add(session);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        var exerciseIds = session.PlannedExercises.Select(pe => pe.ExerciseId)
            .Union(session.Performances.Select(p => p.ExerciseId))
            .ToHashSet();

        var exerciseMap = availableExercises
            .Where(e => exerciseIds.Contains(e.Id))
            .ToDictionary(e => e.Id, e => e.Name);

        return Result<TrainingSessionDto>.Success(session.ToDto(exerciseMap));
    }
}

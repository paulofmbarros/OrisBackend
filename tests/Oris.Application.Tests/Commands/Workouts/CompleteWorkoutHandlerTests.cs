using Moq;
using Oris.Application.Abstractions;
using Oris.Application.Commands.Workouts.CompleteWorkout;
using Oris.Application.Common.Models;
using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Shouldly;

namespace Oris.Application.Tests.Commands.Workouts;

public class CompleteWorkoutHandlerTests
{
    private readonly Mock<ITrainingSessionRepository> _sessionRepositoryMock;
    private readonly Mock<IExerciseRepository> _exerciseRepositoryMock;
    private readonly Mock<IVolumeRepository> _volumeRepositoryMock;
    private readonly Mock<IProgressionRepository> _progressionRepositoryMock;
    private readonly Mock<IProgressionEngine> _progressionEngineMock;
    private readonly Mock<IUnitOfWork> _unitOfWorkMock;
    private readonly CompleteWorkoutHandler _handler;

    public CompleteWorkoutHandlerTests()
    {
        _sessionRepositoryMock = new Mock<ITrainingSessionRepository>();
        _exerciseRepositoryMock = new Mock<IExerciseRepository>();
        _volumeRepositoryMock = new Mock<IVolumeRepository>();
        _progressionRepositoryMock = new Mock<IProgressionRepository>();
        _progressionEngineMock = new Mock<IProgressionEngine>();
        _unitOfWorkMock = new Mock<IUnitOfWork>();
        _handler = new CompleteWorkoutHandler(
            _sessionRepositoryMock.Object,
            _exerciseRepositoryMock.Object,
            _volumeRepositoryMock.Object,
            _progressionRepositoryMock.Object,
            _progressionEngineMock.Object,
            _unitOfWorkMock.Object);
    }

    [Fact]
    public async Task Handle_ShouldReturnSuccess_And_UpdateStates_WhenValid()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var sessionId = Guid.NewGuid();
        var exerciseId = Guid.NewGuid();
        var session = new TrainingSession(userId, DateTime.UtcNow, SessionType.Upper);
        session.AddSetToPerformance(exerciseId, 100, 10, 8);

        var exercise = new Exercise("Bench Press", ExerciseClassification.Compound, MuscleGroup.Chest);
        var volumeState = new WeeklyVolumeState(userId, MuscleGroup.Chest, 10);
        var progressionState = new ProgressionState(userId, exerciseId, 100, 10, 8);

        _sessionRepositoryMock.Setup(x => x.GetByIdAsync(sessionId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(session);

        _exerciseRepositoryMock.Setup(x => x.GetByIdAsync(exerciseId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(exercise);

        _volumeRepositoryMock.Setup(x => x.GetByUserIdAndMuscleGroupAsync(userId, MuscleGroup.Chest, It.IsAny<CancellationToken>()))
            .ReturnsAsync(volumeState);

        _progressionRepositoryMock.Setup(x => x.GetByUserIdAndExerciseIdAsync(userId, exerciseId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(progressionState);

        _progressionEngineMock.Setup(x => x.CalculateNextState(progressionState, It.IsAny<ExercisePerformance>(), It.IsAny<int>()))
            .Returns(Result<ProgressionState>.Success(progressionState));

        var command = new CompleteWorkoutCommand(sessionId);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.ShouldBeTrue();
        session.IsCompleted.ShouldBeTrue();
        volumeState.CurrentSets.ShouldBe(1);

        _volumeRepositoryMock.Verify(x => x.Update(volumeState), Times.Once);
        _progressionRepositoryMock.Verify(x => x.Update(progressionState), Times.Once);
        _sessionRepositoryMock.Verify(x => x.Update(session), Times.Once);
        _unitOfWorkMock.Verify(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_ShouldReturnFailure_WhenSessionNotFound()
    {
        // Arrange
        var sessionId = Guid.NewGuid();
        _sessionRepositoryMock.Setup(x => x.GetByIdAsync(sessionId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((TrainingSession?)null);

        var command = new CompleteWorkoutCommand(sessionId);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsFailure.ShouldBeTrue();
        result.Error.Code.ShouldBe("TrainingSession.NotFound");
    }
}

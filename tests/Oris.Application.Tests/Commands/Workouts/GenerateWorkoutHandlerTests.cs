using Moq;
using Oris.Application.Abstractions;
using Oris.Application.Commands.Workouts.GenerateWorkout;
using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Oris.Domain.Services;
using Shouldly;
using Xunit;

namespace Oris.Application.Tests.Commands.Workouts;

public class GenerateWorkoutHandlerTests
{
    private readonly Mock<IUserRepository> _userRepositoryMock;
    private readonly Mock<ITrainingSessionRepository> _sessionRepositoryMock;
    private readonly Mock<IExerciseRepository> _exerciseRepositoryMock;
    private readonly Mock<IProgressionRepository> _progressionRepositoryMock;
    private readonly Mock<IVolumeRepository> _volumeRepositoryMock;
    private readonly Mock<IWorkoutGenerator> _workoutGeneratorMock;
    private readonly Mock<IUnitOfWork> _unitOfWorkMock;
    private readonly GenerateWorkoutHandler _handler;

    public GenerateWorkoutHandlerTests()
    {
        _userRepositoryMock = new Mock<IUserRepository>();
        _sessionRepositoryMock = new Mock<ITrainingSessionRepository>();
        _exerciseRepositoryMock = new Mock<IExerciseRepository>();
        _progressionRepositoryMock = new Mock<IProgressionRepository>();
        _volumeRepositoryMock = new Mock<IVolumeRepository>();
        _workoutGeneratorMock = new Mock<IWorkoutGenerator>();
        _unitOfWorkMock = new Mock<IUnitOfWork>();
        _handler = new GenerateWorkoutHandler(
            _userRepositoryMock.Object,
            _sessionRepositoryMock.Object,
            _exerciseRepositoryMock.Object,
            _progressionRepositoryMock.Object,
            _volumeRepositoryMock.Object,
            _workoutGeneratorMock.Object,
            _unitOfWorkMock.Object);
    }

    [Fact]
    public async Task Handle_ShouldReturnSuccess_WhenValid()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var user = new User("test@test.com");
        var command = new GenerateWorkoutCommand(userId, DateTime.UtcNow, SessionType.Upper);
        var session = new TrainingSession(userId, DateTime.UtcNow, SessionType.Upper);
        var exercises = new List<Exercise>();

        _userRepositoryMock.Setup(x => x.GetByIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        _sessionRepositoryMock.Setup(x => x.GetActiveSessionByUserIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((TrainingSession?)null);

        _exerciseRepositoryMock.Setup(x => x.GetAllAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(exercises);

        _sessionRepositoryMock.Setup(x => x.GetLastCompletedSessionByUserIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((TrainingSession?)null);

        _progressionRepositoryMock.Setup(x => x.GetByUserIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<ProgressionState>());

        _volumeRepositoryMock.Setup(x => x.GetByUserIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<WeeklyVolumeState>());

        _workoutGeneratorMock.Setup(x => x.GenerateWorkout(user, command.SessionType, command.ScheduledDate, exercises, null, It.IsAny<IEnumerable<ProgressionState>>(), It.IsAny<IEnumerable<WeeklyVolumeState>>()))
            .Returns(session);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.ShouldBeTrue();
        _exerciseRepositoryMock.Verify(x => x.GetAllAsync(It.IsAny<CancellationToken>()), Times.Once);
        _sessionRepositoryMock.Verify(x => x.Add(session), Times.Once);
        _unitOfWorkMock.Verify(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_ShouldReturnFailure_WhenUserNotFound()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var command = new GenerateWorkoutCommand(userId, DateTime.UtcNow, SessionType.Upper);

        _userRepositoryMock.Setup(x => x.GetByIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((User?)null);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsFailure.ShouldBeTrue();
        result.Error.Code.ShouldBe("User.NotFound");
    }

    [Fact]
    public async Task Handle_ShouldReturnFailure_WhenActiveSessionExists()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var user = new User("test@test.com");
        var command = new GenerateWorkoutCommand(userId, DateTime.UtcNow, SessionType.Upper);
        var activeSession = new TrainingSession(userId, DateTime.UtcNow, SessionType.Upper);

        _userRepositoryMock.Setup(x => x.GetByIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        _sessionRepositoryMock.Setup(x => x.GetActiveSessionByUserIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(activeSession);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsFailure.ShouldBeTrue();
        result.Error.Code.ShouldBe("TrainingSession.ActiveExists");
    }
}

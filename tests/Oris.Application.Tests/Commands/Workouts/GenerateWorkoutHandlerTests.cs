using Moq;
using Oris.Application.Abstractions;
using Oris.Application.Commands.Workouts.GenerateWorkout;
using Oris.Application.Common.Models;
using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Shouldly;

namespace Oris.Application.Tests.Commands.Workouts;

public class GenerateWorkoutHandlerTests
{
    private readonly Mock<IUserRepository> _userRepositoryMock;
    private readonly Mock<ITrainingSessionRepository> _sessionRepositoryMock;
    private readonly Mock<IExerciseRepository> _exerciseRepositoryMock;
    private readonly Mock<IWorkoutGenerator> _workoutGeneratorMock;
    private readonly Mock<IUnitOfWork> _unitOfWorkMock;
    private readonly GenerateWorkoutHandler _handler;

    public GenerateWorkoutHandlerTests()
    {
        _userRepositoryMock = new Mock<IUserRepository>();
        _sessionRepositoryMock = new Mock<ITrainingSessionRepository>();
        _exerciseRepositoryMock = new Mock<IExerciseRepository>();
        _workoutGeneratorMock = new Mock<IWorkoutGenerator>();
        _unitOfWorkMock = new Mock<IUnitOfWork>();
        _handler = new GenerateWorkoutHandler(
            _userRepositoryMock.Object,
            _sessionRepositoryMock.Object,
            _exerciseRepositoryMock.Object,
            _workoutGeneratorMock.Object,
            _unitOfWorkMock.Object);
    }

    [Fact]
    public async Task Handle_ShouldReturnSuccess_WhenValid()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var user = new User("test@test.com");
        var command = new GenerateWorkoutCommand(userId, SessionType.Upper, DateTime.UtcNow);
        var session = new TrainingSession(userId, DateTime.UtcNow, SessionType.Upper);

        _userRepositoryMock.Setup(x => x.GetByIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(user);

        _sessionRepositoryMock.Setup(x => x.GetActiveSessionByUserIdAsync(userId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((TrainingSession?)null);

        _workoutGeneratorMock.Setup(x => x.GenerateWorkoutAsync(user, command.SessionType, command.ScheduledDate, It.IsAny<CancellationToken>()))
            .ReturnsAsync(Result<TrainingSession>.Success(session));

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.ShouldBeTrue();
        _sessionRepositoryMock.Verify(x => x.Add(session), Times.Once);
        _unitOfWorkMock.Verify(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task Handle_ShouldReturnFailure_WhenUserNotFound()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var command = new GenerateWorkoutCommand(userId, SessionType.Upper, DateTime.UtcNow);

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
        var command = new GenerateWorkoutCommand(userId, SessionType.Upper, DateTime.UtcNow);
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

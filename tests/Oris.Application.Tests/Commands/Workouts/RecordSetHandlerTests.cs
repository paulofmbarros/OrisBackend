using Moq;
using Oris.Application.Abstractions;
using Oris.Application.Commands.Workouts.RecordSet;
using Oris.Domain.Entities;
using Oris.Domain.Enums;
using Shouldly;

namespace Oris.Application.Tests.Commands.Workouts;

public class RecordSetHandlerTests
{
    private readonly Mock<ITrainingSessionRepository> _sessionRepositoryMock;
    private readonly Mock<IExerciseRepository> _exerciseRepositoryMock;
    private readonly Mock<IUnitOfWork> _unitOfWorkMock;
    private readonly RecordSetHandler _handler;

    public RecordSetHandlerTests()
    {
        _sessionRepositoryMock = new Mock<ITrainingSessionRepository>();
        _exerciseRepositoryMock = new Mock<IExerciseRepository>();
        _unitOfWorkMock = new Mock<IUnitOfWork>();
        _handler = new RecordSetHandler(
            _sessionRepositoryMock.Object,
            _exerciseRepositoryMock.Object,
            _unitOfWorkMock.Object);
    }

    [Fact]
    public async Task Handle_ShouldReturnSuccess_WhenValid()
    {
        // Arrange
        var sessionId = Guid.NewGuid();
        var exerciseId = Guid.NewGuid();
        var session = new TrainingSession(Guid.NewGuid(), DateTime.UtcNow, SessionType.Upper);

        _sessionRepositoryMock.Setup(x => x.GetByIdAsync(sessionId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(session);

        _exerciseRepositoryMock.Setup(x => x.GetByIdsAsync(It.IsAny<IEnumerable<Guid>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<Exercise>());

        var command = new RecordSetCommand(sessionId, exerciseId, 100, 10, 8);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.ShouldBeTrue();
        session.Performances.Count.ShouldBe(1);
        session.Performances.First().ExerciseId.ShouldBe(exerciseId);
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

        var command = new RecordSetCommand(sessionId, Guid.NewGuid(), 100, 10, 8);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsFailure.ShouldBeTrue();
        result.Error.Code.ShouldBe("TrainingSession.NotFound");
    }

    [Fact]
    public async Task Handle_ShouldReturnFailure_WhenSessionAlreadyCompleted()
    {
        // Arrange
        var sessionId = Guid.NewGuid();
        var session = new TrainingSession(Guid.NewGuid(), DateTime.UtcNow, SessionType.Upper);
        session.Complete();

        _sessionRepositoryMock.Setup(x => x.GetByIdAsync(sessionId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(session);

        var command = new RecordSetCommand(sessionId, Guid.NewGuid(), 100, 10, 8);

        // Act
        var result = await _handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsFailure.ShouldBeTrue();
        result.Error.Code.ShouldBe("TrainingSession.AlreadyCompleted");
    }
}

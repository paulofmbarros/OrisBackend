using Oris.Application.Common.Models;
using Shouldly;

namespace Oris.Application.Tests.Common.Models;

public class ResultTests
{
    private static readonly Error TestError = new("Test.Code", "Test message");

    [Fact]
    public void Success_ShouldCreateSuccessfulResult()
    {
        // Act
        var result = Result.Success();

        // Assert
        result.IsSuccess.ShouldBeTrue();
        result.IsFailure.ShouldBeFalse();
        result.Error.ShouldBe(Error.None);
    }

    [Fact]
    public void Failure_ShouldCreateFailureResult()
    {
        // Act
        var result = Result.Failure(TestError);

        // Assert
        result.IsSuccess.ShouldBeFalse();
        result.IsFailure.ShouldBeTrue();
        result.Error.ShouldBe(TestError);
    }

    [Fact]
    public void Failure_WhenErrorIsNone_ShouldThrow()
    {
        // Act
        var action = () => Result.Failure(Error.None);

        // Assert
        Should.Throw<InvalidOperationException>(action);
    }

    [Fact]
    public void Constructor_WhenSuccessAndErrorIsNotNone_ShouldThrow()
    {
        // Act
        var action = () => new ResultProbe(true, TestError);

        // Assert
        Should.Throw<InvalidOperationException>(action);
    }

    [Fact]
    public void Constructor_WhenFailureAndErrorIsNone_ShouldThrow()
    {
        // Act
        var action = () => new ResultProbe(false, Error.None);

        // Assert
        Should.Throw<InvalidOperationException>(action);
    }

    [Fact]
    public void GenericSuccess_ShouldCreateSuccessfulResultWithValue()
    {
        // Act
        var result = Result<int>.Success(42);

        // Assert
        result.IsSuccess.ShouldBeTrue();
        result.IsFailure.ShouldBeFalse();
        result.Error.ShouldBe(Error.None);
        result.Value.ShouldBe(42);
    }

    [Fact]
    public void GenericFailure_ShouldCreateFailureResult()
    {
        // Act
        var result = Result<int>.Failure(TestError);

        // Assert
        result.IsSuccess.ShouldBeFalse();
        result.IsFailure.ShouldBeTrue();
        result.Error.ShouldBe(TestError);
    }

    [Fact]
    public void GenericFailure_WhenErrorIsNone_ShouldThrow()
    {
        // Act
        var action = () => Result<int>.Failure(Error.None);

        // Assert
        Should.Throw<InvalidOperationException>(action);
    }

    [Fact]
    public void GenericValue_WhenResultIsFailure_ShouldThrowWithExpectedMessage()
    {
        // Arrange
        var result = Result<int>.Failure(TestError);

        // Act
        Action action = () =>
        {
            var _ = result.Value;
        };

        // Assert
        var exception = Should.Throw<InvalidOperationException>(action);
        exception.Message.ShouldBe("The value of a failure result can not be accessed.");
    }

    [Fact]
    public void GenericConstructor_WhenSuccessAndErrorIsNotNone_ShouldThrow()
    {
        // Act
        var action = () => new ResultProbe<int>(1, true, TestError);

        // Assert
        Should.Throw<InvalidOperationException>(action);
    }

    [Fact]
    public void GenericConstructor_WhenFailureAndErrorIsNone_ShouldThrow()
    {
        // Act
        var action = () => new ResultProbe<int>(default, false, Error.None);

        // Assert
        Should.Throw<InvalidOperationException>(action);
    }

    private sealed class ResultProbe : Result
    {
        public ResultProbe(bool isSuccess, Error error)
            : base(isSuccess, error)
        {
        }
    }

    private sealed class ResultProbe<T> : Result<T>
    {
        public ResultProbe(T? value, bool isSuccess, Error error)
            : base(value, isSuccess, error)
        {
        }
    }
}

using Cortex.Mediator;

namespace Oris.Application.Abstractions;

public interface ICommandHandler<TCommand, TResponse> : IHandler<TCommand, TResponse>
    where TCommand : ICommand
{
    Task<TResponse> Handle(TCommand command, CancellationToken cancellationToken);

    Task<TResponse> IHandler<TCommand, TResponse>.Handle(TCommand command)
        => Handle(command, CancellationToken.None);
}

public interface ICommandHandler<TCommand> : IHandler<TCommand, Task>
    where TCommand : ICommand
{
    Task Handle(TCommand command, CancellationToken cancellationToken);

    // This is because IHandler expects TResponse (which is Task here)
    async Task<Task> IHandler<TCommand, Task>.Handle(TCommand command)
    {
        await Handle(command, CancellationToken.None);
        return Task.CompletedTask;
    }
}

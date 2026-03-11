using Cortex.Mediator;

namespace Oris.Application.Abstractions;

public interface IQueryHandler<TQuery, TResponse> : IHandler<TQuery, TResponse>
    where TQuery : ICommand
{
    Task<TResponse> Handle(TQuery query, CancellationToken cancellationToken);

    Task<TResponse> IHandler<TQuery, TResponse>.Handle(TQuery query)
        => Handle(query, CancellationToken.None);
}

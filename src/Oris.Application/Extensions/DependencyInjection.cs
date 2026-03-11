using Cortex.Mediator;
using FluentValidation;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Oris.Application.Abstractions;

namespace Oris.Application.Extensions;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services, IConfiguration configuration)
    {
        var assembly = typeof(DependencyInjection).Assembly;

        services.AddScoped<IMediator, Mediator>();

        // Register all handlers automatically
        // A class might implement multiple IHandler interfaces
        var handlerTypes = assembly.GetTypes()
            .Where(t => !t.IsAbstract && !t.IsInterface && t.GetInterfaces().Any(i =>
                i.IsGenericType && i.GetGenericTypeDefinition() == typeof(IHandler<,>)));

        foreach (var handlerType in handlerTypes)
        {
            var handlerInterfaces = handlerType.GetInterfaces().Where(i =>
                i.IsGenericType && i.GetGenericTypeDefinition() == typeof(IHandler<,>));

            foreach (var @interface in handlerInterfaces)
            {
                services.AddScoped(@interface, handlerType);
            }
        }

        services.AddValidatorsFromAssembly(assembly, includeInternalTypes: true);

        return services;
    }
}

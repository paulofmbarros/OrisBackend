using Microsoft.Extensions.DependencyInjection;

namespace Oris.Application.Extensions;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        // Add application services here
        return services;
    }
}

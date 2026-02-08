using Oris.Domain.Entities.Base;

namespace Oris.Domain.Entities;

public class User : AggregateRoot
{
    public string Email { get; private set; }

    public User(string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            throw new ArgumentException("Email cannot be empty.", nameof(email));

        Email = email;
    }

    // Required for EF Core
    private User() : base()
    {
        Email = null!;
    }
}

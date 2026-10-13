namespace Jotter.Application;

public interface ICurrentUser
{
    Guid UserId { get; }

    Guid SessionId { get; }
}

namespace Jotter.Domain;

// Tên không trùng trong phạm vi một owner là bất biến cần truy vấn DB — Application kiểm qua ILabelRepository.
public sealed class Label : Entity, IAggregateRoot, ISyncTracked
{
    private Label()
    {
    }

    private Label(Guid id, Guid ownerId, LabelName name) : base(id)
    {
        OwnerId = ownerId;
        Name = name.Value;
    }

    public Guid OwnerId { get; private init; }

    public string Name { get; private set; } = string.Empty;

    public long ChangeSeq { get; private set; }

    public DateTimeOffset? DeletedAt { get; private set; }

    public bool IsDeleted => DeletedAt is not null;

    public static Result<Label> Create(Guid id, Guid ownerId, string? name)
    {
        if (id == Guid.Empty)
        {
            return LabelErrors.InvalidId;
        }

        var nameResult = LabelName.Create(name);
        if (nameResult.IsFailure)
        {
            return nameResult.Error;
        }

        return new Label(id, ownerId, nameResult.Value);
    }

    public Result Rename(string? name)
    {
        if (IsDeleted)
        {
            return LabelErrors.NotFound;
        }

        var nameResult = LabelName.Create(name);
        if (nameResult.IsFailure)
        {
            return nameResult.Error;
        }

        Name = nameResult.Value.Value;

        return Result.Success();
    }

    public Result MarkDeleted(DateTimeOffset now)
    {
        if (IsDeleted)
        {
            return LabelErrors.NotFound;
        }

        DeletedAt = now;

        return Result.Success();
    }
}

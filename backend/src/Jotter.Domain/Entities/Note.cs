namespace Jotter.Domain;

public sealed class Note : Entity, IAggregateRoot, ISyncTracked
{
    public const long InitialVersion = 1;

    private readonly List<NoteLabelLink> _labels = [];
    private readonly List<Attachment> _attachments = [];

    private Note()
    {
    }

    private Note(
        Guid id,
        Guid ownerId,
        Guid? conflictOfNoteId,
        NoteTitle title,
        NoteContent content,
        DateTimeOffset now) : base(id)
    {
        OwnerId = ownerId;
        ConflictOfNoteId = conflictOfNoteId;
        ApplyContent(title, content);
        Version = InitialVersion;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid OwnerId { get; private init; }

    public Guid? ConflictOfNoteId { get; private init; }

    public string Title { get; private set; } = string.Empty;

    public string Content { get; private set; } = string.Empty;

    public string SearchTitle { get; private set; } = string.Empty;

    public string SearchContent { get; private set; } = string.Empty;

    public bool IsPinned { get; private set; }

    public DateTimeOffset? PinnedAt { get; private set; }

    public bool IsProtected { get; private set; }

    public string? PasswordHash { get; private set; }

    public long Version { get; private set; }

    public long ChangeSeq { get; private set; }

    public DateTimeOffset CreatedAt { get; private init; }

    public DateTimeOffset UpdatedAt { get; private set; }

    public DateTimeOffset? DeletedAt { get; private set; }

    public NoteSummary? Summary { get; private set; }

    public IReadOnlyCollection<NoteLabelLink> Labels => _labels.AsReadOnly();

    public IReadOnlyCollection<Attachment> Attachments => _attachments.AsReadOnly();

    public bool IsDeleted => DeletedAt is not null;

    public static Result<Note> Create(Guid id, Guid ownerId, string? title, string? content, DateTimeOffset now) =>
        CreateCore(id, ownerId, conflictOfNoteId: null, title, content, now);

    // ownerId là người vừa soạn nội dung bị từ chối, KHÔNG phải chủ của note gốc.
    public static Result<Note> CreateConflictCopy(
        Guid id,
        Guid ownerId,
        Guid sourceNoteId,
        string? title,
        string? content,
        DateTimeOffset now)
    {
        if (sourceNoteId == Guid.Empty || sourceNoteId == id)
        {
            return NoteErrors.InvalidConflictSource;
        }

        return CreateCore(id, ownerId, sourceNoteId, title, content, now);
    }

    public Result UpdateContent(long baseVersion, string? title, string? content, DateTimeOffset now)
    {
        var guard = EnsureNotDeleted();
        if (guard.IsFailure)
        {
            return guard;
        }

        var titleResult = NoteTitle.Create(title);
        if (titleResult.IsFailure)
        {
            return titleResult.Error;
        }

        var contentResult = NoteContent.Create(content);
        if (contentResult.IsFailure)
        {
            return contentResult.Error;
        }

        // Xét trước VersionConflict: gửi lại đúng nội dung server đang có (vd. response bị rớt) không làm mất
        // dữ liệu của ai, nên không được sinh ra Conflict Copy giả.
        if (Title == titleResult.Value.Value && Content == contentResult.Value.Value)
        {
            return Result.Success();
        }

        if (baseVersion != Version)
        {
            return NoteErrors.VersionConflict;
        }

        ApplyContent(titleResult.Value, contentResult.Value);
        Version++;
        UpdatedAt = now;

        return Result.Success();
    }

    public Result Pin(DateTimeOffset now)
    {
        var guard = EnsureNotDeleted();
        if (guard.IsFailure)
        {
            return guard;
        }

        // Ghim lại không đổi PinnedAt để thứ tự giữa các note đã ghim giữ ổn định.
        if (IsPinned)
        {
            return Result.Success();
        }

        IsPinned = true;
        PinnedAt = now;

        return Result.Success();
    }

    public Result Unpin()
    {
        var guard = EnsureNotDeleted();
        if (guard.IsFailure)
        {
            return guard;
        }

        if (!IsPinned)
        {
            return Result.Success();
        }

        IsPinned = false;
        PinnedAt = null;

        return Result.Success();
    }

    // Labels phải đã được Application xác nhận là nhãn còn sống của chính chủ sở hữu.
    public Result SetLabels(IEnumerable<Guid> labelIds)
    {
        var guard = EnsureNotDeleted();
        if (guard.IsFailure)
        {
            return guard;
        }

        var desired = labelIds.ToHashSet();
        if (desired.Contains(Guid.Empty))
        {
            return LabelErrors.InvalidId;
        }

        var removedCount = _labels.RemoveAll(link => !desired.Contains(link.LabelId));
        var addedIds = desired.Except(_labels.Select(link => link.LabelId)).ToList();
        _labels.AddRange(addedIds.Select(labelId => new NoteLabelLink(Id, labelId)));

        if (removedCount > 0 || addedIds.Count > 0)
        {
            RequestNewChangeSeq();
        }

        return Result.Success();
    }

    public void DetachLabel(Guid labelId)
    {
        if (_labels.RemoveAll(link => link.LabelId == labelId) > 0)
        {
            RequestNewChangeSeq();
        }
    }

    public Result<Attachment> AddAttachment(
        string? fileName,
        string mimeType,
        long sizeBytes,
        string storageKey,
        Guid uploadedBy,
        DateTimeOffset now)
    {
        var guard = EnsureNotDeleted();
        if (guard.IsFailure)
        {
            return guard.Error;
        }

        var result = Attachment.Create(Id, fileName, mimeType, sizeBytes, storageKey, uploadedBy, now);
        if (result.IsSuccess)
        {
            _attachments.Add(result.Value);
        }

        return result;
    }

    public Result RemoveAttachment(Guid attachmentId, DateTimeOffset now)
    {
        var guard = EnsureNotDeleted();
        if (guard.IsFailure)
        {
            return guard;
        }

        var attachment = _attachments.SingleOrDefault(a => a.Id == attachmentId && !a.IsDeleted);
        if (attachment is null)
        {
            return NoteErrors.AttachmentNotFound;
        }

        attachment.MarkDeleted(now);

        return Result.Success();
    }

    public Result EnableProtection(NotePassword password)
    {
        var guard = EnsureNotDeleted();
        if (guard.IsFailure)
        {
            return guard;
        }

        if (IsProtected)
        {
            return ProtectionErrors.AlreadyProtected;
        }

        IsProtected = true;
        PasswordHash = password.Hash;

        return Result.Success();
    }

    // Xác minh mật khẩu hiện tại là việc của Application (cần INotePasswordHasher) và phải làm TRƯỚC khi gọi.
    public Result ChangePassword(NotePassword newPassword)
    {
        var guard = EnsureProtected();
        if (guard.IsFailure)
        {
            return guard;
        }

        PasswordHash = newPassword.Hash;

        return Result.Success();
    }

    public Result DisableProtection()
    {
        var guard = EnsureProtected();
        if (guard.IsFailure)
        {
            return guard;
        }

        IsProtected = false;
        PasswordHash = null;

        return Result.Success();
    }

    public Result<NoteUnlockSession> IssueUnlockSession(Guid userId, DateTimeOffset now)
    {
        var guard = EnsureProtected();
        if (guard.IsFailure)
        {
            return guard.Error;
        }

        return NoteUnlockSession.Issue(Id, userId, now);
    }

    public Result EnsureSummarizable()
    {
        var guard = EnsureNotDeleted();
        if (guard.IsFailure)
        {
            return guard;
        }

        if (string.IsNullOrWhiteSpace(Content))
        {
            return NoteErrors.EmptyContent;
        }

        return Result.Success();
    }

    // Không đụng Version hay ChangeSeq: tóm tắt nằm ngoài realtime và đồng bộ.
    public Result SetSummary(string? summaryText, DateTimeOffset now)
    {
        var guard = EnsureNotDeleted();
        if (guard.IsFailure)
        {
            return guard;
        }

        var text = summaryText?.Trim();
        if (string.IsNullOrEmpty(text))
        {
            return NoteErrors.EmptySummary;
        }

        if (Summary is null)
        {
            Summary = NoteSummary.Create(Id, text, now);
        }
        else
        {
            Summary.Replace(text, now);
        }

        return Result.Success();
    }

    public Result MarkDeleted(DateTimeOffset now)
    {
        var guard = EnsureNotDeleted();
        if (guard.IsFailure)
        {
            return guard;
        }

        DeletedAt = now;

        foreach (var attachment in _attachments.Where(a => !a.IsDeleted))
        {
            attachment.MarkDeleted(now);
        }

        return Result.Success();
    }

    private static Result<Note> CreateCore(
        Guid id,
        Guid ownerId,
        Guid? conflictOfNoteId,
        string? title,
        string? content,
        DateTimeOffset now)
    {
        if (id == Guid.Empty)
        {
            return NoteErrors.InvalidId;
        }

        var titleResult = NoteTitle.Create(title);
        if (titleResult.IsFailure)
        {
            return titleResult.Error;
        }

        var contentResult = NoteContent.Create(content);
        if (contentResult.IsFailure)
        {
            return contentResult.Error;
        }

        if (titleResult.Value.IsBlank && contentResult.Value.IsBlank)
        {
            return NoteErrors.EmptyNote;
        }

        return new Note(id, ownerId, conflictOfNoteId, titleResult.Value, contentResult.Value, now);
    }

    private void ApplyContent(NoteTitle title, NoteContent content)
    {
        var searchText = SearchText.From(title, content);

        Title = title.Value;
        Content = content.Value;
        SearchTitle = searchText.Title;
        SearchContent = searchText.Content;
    }

    private Result EnsureNotDeleted() =>
        IsDeleted ? Result.Failure(NoteErrors.NotFound) : Result.Success();

    private Result EnsureProtected()
    {
        var guard = EnsureNotDeleted();
        if (guard.IsFailure)
        {
            return guard;
        }

        return IsProtected ? Result.Success() : Result.Failure(ProtectionErrors.NotProtected);
    }

    // Liên kết nhãn không có changeSeq riêng nên chỉnh nó không làm dòng Note thay đổi.
    // Đưa về 0 để EF thấy Note bị sửa; ChangeSeqInterceptor sẽ cấp giá trị thật lúc lưu.
    private void RequestNewChangeSeq() => ChangeSeq = 0;
}

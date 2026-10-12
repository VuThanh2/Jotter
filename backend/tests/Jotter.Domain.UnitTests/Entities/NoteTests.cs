using Xunit;

namespace Jotter.Domain.UnitTests;

public sealed class NoteTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 12, 8, 0, 0, TimeSpan.Zero);
    private static readonly Guid OwnerId = Guid.CreateVersion7();

    [Fact]
    public void Create_StartsAtInitialVersion_WithNormalizedSearchText()
    {
        var note = Note.Create(Guid.CreateVersion7(), OwnerId, "Ghi Chú", "Đi chợ", Now).Value;

        Assert.Equal(Note.InitialVersion, note.Version);
        Assert.Equal("ghi chu", note.SearchTitle);
        Assert.Equal("di cho", note.SearchContent);
        Assert.Equal(Now, note.UpdatedAt);
    }

    [Fact]
    public void Create_RejectsEmptyNote()
    {
        var result = Note.Create(Guid.CreateVersion7(), OwnerId, " ", "", Now);

        Assert.Equal(NoteErrors.EmptyNote, result.Error);
    }

    [Fact]
    public void Create_RejectsEmptyId()
    {
        var result = Note.Create(Guid.Empty, OwnerId, "a", "b", Now);

        Assert.Equal(NoteErrors.InvalidId, result.Error);
    }

    [Fact]
    public void CreateConflictCopy_BelongsToWriter_AndReferencesSource()
    {
        var sourceId = Guid.CreateVersion7();
        var writerId = Guid.CreateVersion7();

        var copy = Note.CreateConflictCopy(Guid.CreateVersion7(), writerId, sourceId, "a", "b", Now).Value;

        Assert.Equal(writerId, copy.OwnerId);
        Assert.Equal(sourceId, copy.ConflictOfNoteId);
        Assert.Empty(copy.Labels);
        Assert.False(copy.IsPinned);
        Assert.False(copy.IsProtected);
    }

    [Fact]
    public void CreateConflictCopy_RejectsSelfReference()
    {
        var id = Guid.CreateVersion7();

        var result = Note.CreateConflictCopy(id, OwnerId, id, "a", "b", Now);

        Assert.Equal(NoteErrors.InvalidConflictSource, result.Error);
    }

    [Fact]
    public void UpdateContent_IncrementsVersion_WhenContentChanges()
    {
        var note = NewNote();
        var later = Now.AddMinutes(1);

        var result = note.UpdateContent(note.Version, "Tiêu đề", "Nội dung mới", later);

        Assert.True(result.IsSuccess);
        Assert.Equal(Note.InitialVersion + 1, note.Version);
        Assert.Equal(later, note.UpdatedAt);
        Assert.Equal("noi dung moi", note.SearchContent);
    }

    [Fact]
    public void UpdateContent_KeepsVersion_WhenNothingChanges()
    {
        var note = NewNote();

        var result = note.UpdateContent(note.Version, note.Title, note.Content, Now.AddMinutes(1));

        Assert.True(result.IsSuccess);
        Assert.Equal(Note.InitialVersion, note.Version);
        Assert.Equal(Now, note.UpdatedAt);
    }

    [Fact]
    public void UpdateContent_RejectsStaleBaseVersion()
    {
        var note = NewNote();
        note.UpdateContent(note.Version, "x", "y", Now);

        var result = note.UpdateContent(Note.InitialVersion, "z", "w", Now);

        Assert.Equal(NoteErrors.VersionConflict, result.Error);
        Assert.Equal("x", note.Title);
    }

    [Fact]
    public void UpdateContent_AcceptsStaleBaseVersion_WhenContentAlreadyMatchesServer()
    {
        var note = NewNote();
        note.UpdateContent(note.Version, "x", "y", Now);

        var result = note.UpdateContent(Note.InitialVersion, "x", "y", Now.AddMinutes(1));

        Assert.True(result.IsSuccess);
        Assert.Equal(Note.InitialVersion + 1, note.Version);
    }

    [Fact]
    public void UpdateContent_AllowsClearingEverything()
    {
        var note = NewNote();

        var result = note.UpdateContent(note.Version, "", "", Now);

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public void UpdateContent_RejectsTooLongTitle()
    {
        var note = NewNote();

        var result = note.UpdateContent(note.Version, new string('a', NoteTitle.MaxLength + 1), "", Now);

        Assert.Equal(NoteErrors.TitleTooLong, result.Error);
    }

    [Fact]
    public void Pin_DoesNotChangeVersion_AndKeepsOriginalPinnedAt()
    {
        var note = NewNote();

        note.Pin(Now);
        note.Pin(Now.AddHours(1));

        Assert.True(note.IsPinned);
        Assert.Equal(Now, note.PinnedAt);
        Assert.Equal(Note.InitialVersion, note.Version);
    }

    [Fact]
    public void Unpin_ClearsPinnedAt()
    {
        var note = NewNote();
        note.Pin(Now);

        note.Unpin();

        Assert.False(note.IsPinned);
        Assert.Null(note.PinnedAt);
    }

    [Fact]
    public void SetLabels_ReplacesWholeSet_WithoutDuplicates()
    {
        var note = NewNote();
        var a = Guid.CreateVersion7();
        var b = Guid.CreateVersion7();
        var c = Guid.CreateVersion7();
        note.SetLabels([a, b]);

        var result = note.SetLabels([b, c, c]);

        Assert.True(result.IsSuccess);
        Assert.Equal(new HashSet<Guid> { b, c }, note.Labels.Select(l => l.LabelId).ToHashSet());
        Assert.Equal(Note.InitialVersion, note.Version);
    }

    [Fact]
    public void SetLabels_RejectsEmptyLabelId()
    {
        var note = NewNote();

        var result = note.SetLabels([Guid.Empty]);

        Assert.Equal(LabelErrors.InvalidId, result.Error);
    }

    [Fact]
    public void DetachLabel_RemovesOnlyThatLabel()
    {
        var note = NewNote();
        var keep = Guid.CreateVersion7();
        var drop = Guid.CreateVersion7();
        note.SetLabels([keep, drop]);

        note.DetachLabel(drop);

        Assert.Equal(keep, Assert.Single(note.Labels).LabelId);
    }

    [Fact]
    public void Protection_Lifecycle()
    {
        var note = NewNote();

        Assert.Equal(ProtectionErrors.NotProtected, note.DisableProtection().Error);
        Assert.True(note.EnableProtection(NotePassword.FromHash("hash-1")).IsSuccess);
        Assert.Equal(ProtectionErrors.AlreadyProtected, note.EnableProtection(NotePassword.FromHash("x")).Error);

        note.ChangePassword(NotePassword.FromHash("hash-2"));
        Assert.Equal("hash-2", note.PasswordHash);

        note.DisableProtection();
        Assert.False(note.IsProtected);
        Assert.Null(note.PasswordHash);
    }

    [Fact]
    public void IssueUnlockSession_RequiresProtection()
    {
        var note = NewNote();

        Assert.Equal(ProtectionErrors.NotProtected, note.IssueUnlockSession(OwnerId, Now).Error);

        note.EnableProtection(NotePassword.FromHash("hash"));
        var session = note.IssueUnlockSession(OwnerId, Now).Value;

        Assert.Equal(note.Id, session.NoteId);
        Assert.True(session.IsActiveAt(Now));
        Assert.False(session.IsActiveAt(Now + NoteUnlockSession.Lifetime));
    }

    [Fact]
    public void SetSummary_ReplacesInPlace_WithoutTouchingVersion()
    {
        var note = NewNote();
        note.SetSummary("first", Now);
        var summary = note.Summary;

        note.SetSummary("second", Now.AddMinutes(5));

        Assert.Same(summary, note.Summary);
        Assert.Equal("second", note.Summary!.SummaryText);
        Assert.Equal(Now.AddMinutes(5), note.Summary.GeneratedAt);
        Assert.Equal(Note.InitialVersion, note.Version);
    }

    [Fact]
    public void EnsureSummarizable_RejectsBlankContent()
    {
        var note = Note.Create(Guid.CreateVersion7(), OwnerId, "Only title", "  ", Now).Value;

        Assert.Equal(NoteErrors.EmptyContent, note.EnsureSummarizable().Error);
    }

    [Fact]
    public void Attachments_AddAndRemove()
    {
        var note = NewNote();

        var attachment = note.AddAttachment(@"C:\fakepath\photo.png", "image/png", 10, "key", OwnerId, Now).Value;
        Assert.Equal("photo.png", attachment.FileName);

        Assert.True(note.RemoveAttachment(attachment.Id, Now).IsSuccess);
        Assert.True(attachment.IsDeleted);
        Assert.Equal(NoteErrors.AttachmentNotFound, note.RemoveAttachment(attachment.Id, Now).Error);
    }

    [Theory]
    [InlineData(0, "EmptyFile")]
    [InlineData(Attachment.MaxSizeBytes + 1, "FileTooLarge")]
    public void AddAttachment_ValidatesSize(long size, string expectedCode)
    {
        var note = NewNote();

        var result = note.AddAttachment("a.pdf", "application/pdf", size, "key", OwnerId, Now);

        Assert.Equal(expectedCode, result.Error.Code);
    }

    [Fact]
    public void MarkDeleted_TombstonesNoteAndAttachments_AndBlocksFurtherChanges()
    {
        var note = NewNote();
        var attachment = note.AddAttachment("a.txt", "text/plain", 1, "key", OwnerId, Now).Value;

        note.MarkDeleted(Now);

        Assert.True(note.IsDeleted);
        Assert.True(attachment.IsDeleted);
        Assert.Equal(NoteErrors.NotFound, note.UpdateContent(note.Version, "a", "b", Now).Error);
        Assert.Equal(NoteErrors.NotFound, note.Pin(Now).Error);
        Assert.Equal(NoteErrors.NotFound, note.MarkDeleted(Now).Error);
    }

    private static Note NewNote() =>
        Note.Create(Guid.CreateVersion7(), OwnerId, "Tiêu đề", "Nội dung", Now).Value;
}

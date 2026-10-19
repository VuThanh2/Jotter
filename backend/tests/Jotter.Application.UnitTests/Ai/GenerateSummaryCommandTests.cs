using Jotter.Domain;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class GenerateSummaryCommandTests
{
    private readonly Guid _userId = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly INoteAccessPolicy _accessPolicy = Substitute.For<INoteAccessPolicy>();
    private readonly INoteRepository _notes = Substitute.For<INoteRepository>();
    private readonly ILlmService _llm = Substitute.For<ILlmService>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();
    private readonly Note _note;

    public GenerateSummaryCommandTests()
    {
        _currentUser.UserId.Returns(_userId);
        _note = TestData.NewNote(_userId, "Họp nhóm", "Chốt phạm vi đồ án và chia việc.");
        _notes.GetByIdAsync(_note.Id, Arg.Any<CancellationToken>()).Returns(_note);
        GivenAccess(TestData.Access(NoteAccessLevel.ReadOnly));
    }

    // Nội dung note đang khoá không bao giờ được rời server để đi tới provider LLM.
    [Fact]
    public async Task LockedNote_IsNeverSentToLlm()
    {
        GivenAccess(TestData.Access(NoteAccessLevel.Owner, isProtected: true));

        var result = await ExecuteAsync();

        Assert.Equal(AccessErrors.NoteLocked, result.Error);
        Assert.Empty(_llm.ReceivedCalls());
    }

    [Theory]
    [InlineData(LlmFailureKind.Unavailable, "LlmUnavailable")]
    [InlineData(LlmFailureKind.QuotaExceeded, "LlmQuotaExceeded")]
    public async Task ProviderFailingBeforeFirstChunk_IsReportedAsHttpError_NotAsBrokenStream(
        LlmFailureKind kind,
        string expectedCode)
    {
        GivenLlmStream(LlmStreams.FailingAfter(kind));

        var result = await ExecuteAsync();

        Assert.Equal(expectedCode, result.Error.Code);
    }

    // Bản tóm tắt dở dang không được ghi đè bản cũ.
    [Fact]
    public async Task ProviderFailingMidStream_EmitsFailureEvent_AndSavesNothing()
    {
        GivenLlmStream(LlmStreams.FailingAfter(LlmFailureKind.Unavailable, "Nhóm chốt "));

        var events = await CollectAsync((await ExecuteAsync()).Value);

        Assert.Collection(
            events,
            e => Assert.Equal(new GenerateSummaryDeltaDto("Nhóm chốt "), e),
            e => Assert.Equal(AiErrors.LlmUnavailable.Code, Assert.IsType<GenerateSummaryFailedDto>(e).Code));
        Assert.Null(_note.Summary);
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    // Tóm tắt lưu tách biệt: không đụng Content, không tăng Version (tránh xung đột giả cho editor đang mở).
    [Fact]
    public async Task CompletedStream_SavesSummarySeparately_WithoutTouchingNoteContentOrVersion()
    {
        GivenLlmStream(LlmStreams.Of("Nhóm chốt ", "phạm vi."));

        var events = await CollectAsync((await ExecuteAsync()).Value);

        var completed = Assert.IsType<GenerateSummaryCompletedDto>(events[^1]);
        Assert.Equal("Nhóm chốt phạm vi.", completed.SummaryText);
        Assert.Equal("Nhóm chốt phạm vi.", _note.Summary!.SummaryText);
        Assert.Equal("Chốt phạm vi đồ án và chia việc.", _note.Content);
        Assert.Equal(Note.InitialVersion, _note.Version);
        await _unitOfWork.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    private void GivenAccess(NoteAccess access) =>
        _accessPolicy.GetAccessAsync(_userId, _note.Id, Arg.Any<CancellationToken>()).Returns(access);

    private void GivenLlmStream(IAsyncEnumerable<string> stream) =>
        _llm.SummarizeAsync(_note.Title, _note.Content, Arg.Any<CancellationToken>()).Returns(stream);

    private Task<Result<IAsyncEnumerable<GenerateSummaryEventDto>>> ExecuteAsync() =>
        new GenerateSummaryCommand(_currentUser, _accessPolicy, _notes, _llm, _unitOfWork, new FixedClock(TestData.Now))
            .ExecuteAsync(_note.Id, TestData.Ct);

    private static async Task<List<GenerateSummaryEventDto>> CollectAsync(IAsyncEnumerable<GenerateSummaryEventDto> stream)
    {
        var events = new List<GenerateSummaryEventDto>();
        await foreach (var e in stream.WithCancellation(TestData.Ct))
        {
            events.Add(e);
        }

        return events;
    }
}

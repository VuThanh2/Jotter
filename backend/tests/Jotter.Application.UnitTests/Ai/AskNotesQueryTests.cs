using Jotter.Domain;
using NSubstitute;
using NSubstitute.ExceptionExtensions;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class AskNotesQueryTests
{
    private const string Question = "Deadline đồ án là khi nào?";

    private readonly Guid _userId = Guid.CreateVersion7();
    private readonly Guid _noteA = Guid.CreateVersion7();
    private readonly Guid _noteB = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly INoteAccessPolicy _accessPolicy = Substitute.For<INoteAccessPolicy>();
    private readonly IEmbeddingStore _embeddings = Substitute.For<IEmbeddingStore>();
    private readonly ILlmService _llm = Substitute.For<ILlmService>();

    public AskNotesQueryTests()
    {
        _currentUser.UserId.Returns(_userId);
        _accessPolicy.ListContentReadableNoteIdsAsync(_userId, Arg.Any<CancellationToken>())
            .Returns(new List<Guid> { _noteA, _noteB });
        _llm.EmbedAsync(Arg.Any<IReadOnlyList<string>>(), Arg.Any<CancellationToken>())
            .Returns(new List<float[]> { new[] { 1f } });
        _llm.AnswerAsync(Question, Arg.Any<IReadOnlyList<ContextPassage>>(), Arg.Any<CancellationToken>())
            .Returns(new LlmAnswer("Ngày 20/12.", HasEnoughContext: true));
    }

    // Lọc quyền phải xảy ra TRƯỚC khi tính độ tương đồng: kho vector chỉ được nhìn thấy đúng tập note đọc được.
    [Fact]
    public async Task Retrieval_IsRestrictedToNotesTheCallerCanRead()
    {
        GivenMatches(Match(_noteA, 0.9f));

        await ExecuteAsync();

        await _embeddings.Received(1).SearchAsync(
            Arg.Is<IReadOnlyCollection<Guid>>(ids => ids.SequenceEqual(new[] { _noteA, _noteB })),
            Arg.Any<float[]>(),
            Arg.Any<int>(),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task NoReadableNotes_AnswersNotEnoughContext_WithoutCallingLlm()
    {
        _accessPolicy.ListContentReadableNoteIdsAsync(_userId, Arg.Any<CancellationToken>()).Returns(new List<Guid>());

        var result = await ExecuteAsync();

        Assert.False(result.Value.HasEnoughContext);
        Assert.Empty(_llm.ReceivedCalls());
    }

    // Không có đoạn đủ liên quan thì phải nói thẳng, không đưa ngữ cảnh rác cho LLM để nó bịa.
    [Fact]
    public async Task OnlyIrrelevantMatches_AnswersNotEnoughContext_WithoutAskingLlm()
    {
        GivenMatches(Match(_noteA, 0.1f), Match(_noteB, 0.05f));

        var result = await ExecuteAsync();

        Assert.False(result.Value.HasEnoughContext);
        Assert.Empty(result.Value.Citations);
        await _llm.DidNotReceive().AnswerAsync(
            Arg.Any<string>(), Arg.Any<IReadOnlyList<ContextPassage>>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Citations_ListEachSourceNoteOnce_StrongestFirst()
    {
        GivenMatches(Match(_noteA, 0.86f), Match(_noteB, 0.88f), Match(_noteA, 0.9f));

        var result = await ExecuteAsync();

        Assert.Equal(new[] { _noteA, _noteB }, result.Value.Citations.Select(c => c.NoteId));
        Assert.Equal(0.9f, result.Value.Citations[0].Score);
    }

    // Note lạc đề vẫn qua được ngưỡng tuyệt đối (embedding cho điểm ~0.5 cả với note không liên quan) nhưng bị note
    // nguồn bỏ xa: nó vẫn là ngữ cảnh cho LLM, chỉ không được hiện thành trích dẫn như thể là nguồn của câu trả lời.
    [Fact]
    public async Task NotesFarBehindTheBestMatch_AreGivenToTheLlm_ButNotCited()
    {
        GivenMatches(Match(_noteA, 0.77f), Match(_noteB, 0.55f));

        var result = await ExecuteAsync();

        Assert.Equal(new[] { _noteA }, result.Value.Citations.Select(c => c.NoteId));
        await _llm.Received(1).AnswerAsync(
            Question,
            Arg.Is<IReadOnlyList<ContextPassage>>(passages => passages.Count == 2),
            Arg.Any<CancellationToken>());
    }

    // LLM tự nhận không đủ căn cứ thì không được gắn trích dẫn giả như thể câu trả lời có nguồn,
    // và câu báo dùng chung câu cố định thay vì lời của model (có khi bằng tiếng Anh).
    [Fact]
    public async Task LlmAdmittingInsufficientContext_ReturnsNoCitations()
    {
        GivenMatches(Match(_noteA, 0.9f));
        _llm.AnswerAsync(Question, Arg.Any<IReadOnlyList<ContextPassage>>(), Arg.Any<CancellationToken>())
            .Returns(new LlmAnswer("The notes do not contain the answer.", HasEnoughContext: false));

        var result = await ExecuteAsync();

        Assert.False(result.Value.HasEnoughContext);
        Assert.Empty(result.Value.Citations);
        Assert.Equal(await NoContextAnswerAsync(), result.Value.Answer);
    }

    [Fact]
    public async Task ProviderOutage_IsReportedAsLlmUnavailable()
    {
        _llm.EmbedAsync(Arg.Any<IReadOnlyList<string>>(), Arg.Any<CancellationToken>())
            .ThrowsAsync(new LlmException(LlmFailureKind.Unavailable, "down"));

        var result = await ExecuteAsync();

        Assert.Equal(AiErrors.LlmUnavailable, result.Error);
    }

    // Câu báo không tìm thấy của chính Query, lấy qua nhánh không có note nào đọc được để test không chép lại chuỗi.
    private async Task<string> NoContextAnswerAsync()
    {
        var noNotes = Substitute.For<INoteAccessPolicy>();
        noNotes.ListContentReadableNoteIdsAsync(_userId, Arg.Any<CancellationToken>()).Returns(new List<Guid>());

        var result = await new AskNotesQuery(_currentUser, noNotes, _embeddings, _llm)
            .ExecuteAsync(new AskNotesInputDto(Question), TestData.Ct);
        return result.Value.Answer;
    }

    private EmbeddingMatch Match(Guid noteId, float score) => new(noteId, "Đồ án", $"Đoạn {score}", score);

    private void GivenMatches(params EmbeddingMatch[] matches) =>
        _embeddings.SearchAsync(
                Arg.Any<IReadOnlyCollection<Guid>>(), Arg.Any<float[]>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
            .Returns(matches);

    private Task<Result<AskNotesOutputDto>> ExecuteAsync() =>
        new AskNotesQuery(_currentUser, _accessPolicy, _embeddings, _llm)
            .ExecuteAsync(new AskNotesInputDto(Question), TestData.Ct);
}

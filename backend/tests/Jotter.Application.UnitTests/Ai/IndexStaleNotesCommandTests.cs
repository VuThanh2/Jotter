using Jotter.Domain;
using NSubstitute;
using NSubstitute.ExceptionExtensions;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class IndexStaleNotesCommandTests
{
    private readonly IEmbeddingStore _embeddings = Substitute.For<IEmbeddingStore>();
    private readonly ILlmService _llm = Substitute.For<ILlmService>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();

    public IndexStaleNotesCommandTests() =>
        _llm.EmbedAsync(Arg.Any<IReadOnlyList<string>>(), Arg.Any<CancellationToken>())
            .Returns(call => call.Arg<IReadOnlyList<string>>().Select(_ => new[] { 1f }).ToList());

    [Fact]
    public async Task DeletedOrBlankNotes_AreRemovedFromIndex_WithoutCallingLlm()
    {
        var deleted = new StaleNote(Guid.CreateVersion7(), "Cũ", "Đã xoá", 3, IsDeleted: true);
        var blank = new StaleNote(Guid.CreateVersion7(), "  ", "", 2, IsDeleted: false);
        GivenStaleNotes(deleted, blank);

        var result = await ExecuteAsync();

        Assert.Equal(2, result.Value);
        await _embeddings.Received(1).RemoveAsync(deleted.NoteId, Arg.Any<CancellationToken>());
        await _embeddings.Received(1).RemoveAsync(blank.NoteId, Arg.Any<CancellationToken>());
        Assert.Empty(_llm.ReceivedCalls());
    }

    // Lập chỉ mục lỗi không được làm mất phần đã xong; lần chạy sau tự nhặt lại phần còn lại.
    [Fact]
    public async Task ProviderOutageMidBatch_KeepsNotesAlreadyIndexed()
    {
        var first = new StaleNote(Guid.CreateVersion7(), "A", "Nội dung A", 2, IsDeleted: false);
        var second = new StaleNote(Guid.CreateVersion7(), "B", "Nội dung B", 5, IsDeleted: false);
        GivenStaleNotes(first, second);
        _llm.EmbedAsync(Arg.Is<IReadOnlyList<string>>(texts => texts[0].StartsWith('B')), Arg.Any<CancellationToken>())
            .ThrowsAsync(new LlmException(LlmFailureKind.Unavailable, "down"));

        var result = await ExecuteAsync();

        Assert.Equal(AiErrors.LlmUnavailable, result.Error);
        await _embeddings.Received(1).ReplaceAsync(
            first.NoteId, 2, Arg.Any<IReadOnlyList<EmbeddedChunk>>(), Arg.Any<CancellationToken>());
        await _embeddings.DidNotReceive().ReplaceAsync(
            second.NoteId, Arg.Any<long>(), Arg.Any<IReadOnlyList<EmbeddedChunk>>(), Arg.Any<CancellationToken>());
        await _unitOfWork.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    // Note dài phải được cắt vừa giới hạn của model nhưng không được rơi mất hay chẻ đôi từ nào.
    [Fact]
    public async Task LongNote_IsSplitIntoBoundedChunks_WithoutLosingOrSplittingWords()
    {
        var words = Enumerable.Range(0, 2_000).Select(i => $"tu{i}").ToList();
        var note = new StaleNote(Guid.CreateVersion7(), "Tiêu đề", string.Join(' ', words), 7, IsDeleted: false);
        GivenStaleNotes(note);
        IReadOnlyList<EmbeddedChunk>? chunks = null;
        _embeddings
            .When(store => store.ReplaceAsync(
                note.NoteId, 7, Arg.Any<IReadOnlyList<EmbeddedChunk>>(), Arg.Any<CancellationToken>()))
            .Do(call => chunks = call.ArgAt<IReadOnlyList<EmbeddedChunk>>(2));

        await ExecuteAsync();

        Assert.NotNull(chunks);
        Assert.True(chunks.Count > 1);
        Assert.All(chunks, chunk => Assert.StartsWith("Tiêu đề\n", chunk.Text));
        var bodies = chunks.Select(chunk => chunk.Text["Tiêu đề\n".Length..]).ToList();
        Assert.All(bodies, body => Assert.True(body.Length <= 2_000));
        Assert.Equal(words, bodies.SelectMany(body => body.Split(' ')));
    }

    private void GivenStaleNotes(params StaleNote[] notes) =>
        _embeddings.ListStaleNotesAsync(Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns(notes);

    private Task<Result<int>> ExecuteAsync() =>
        new IndexStaleNotesCommand(_embeddings, _llm, _unitOfWork).ExecuteAsync(TestData.Ct);
}

using Jotter.Domain;

namespace Jotter.Application;

public sealed class AskNotesQuery(
    ICurrentUser currentUser,
    INoteAccessPolicy accessPolicy,
    IEmbeddingStore embeddings,
    ILlmService llm)
{
    // topK do server quyết định, không nhận từ client.
    private const int TopK = 8;

    // Đoạn có độ tương đồng cosine dưới ngưỡng coi như không liên quan; không còn đoạn nào thì nói thẳng là không đủ thông tin.
    private const float MinRelevanceScore = 0.3f;

    // Điểm tuyệt đối của embedding không tách được note nguồn khỏi note lạc đề (đo với gemini-embedding-2: note đúng có
    // khi chỉ 0.56, note lạc đề có khi tới 0.65), nhưng note nguồn luôn đứng đầu và bỏ xa phần còn lại. Nên chỉ trích dẫn
    // những note sát điểm cao nhất; LLM vẫn nhận đủ các đoạn trên MinRelevanceScore làm ngữ cảnh.
    private const float CitationScoreMargin = 0.05f;

    private const int MaxExcerptLength = 200;

    private const string NotEnoughContextAnswer =
        "Không tìm thấy thông tin liên quan trong các note bạn có quyền truy cập.";

    public async Task<Result<AskNotesOutputDto>> ExecuteAsync(AskNotesInputDto input, CancellationToken ct)
    {
        try
        {
            return await AnswerFromNotesAsync(input.Question, ct);
        }
        catch (LlmException ex)
        {
            return AiErrors.From(ex);
        }
    }

    private async Task<AskNotesOutputDto> AnswerFromNotesAsync(string question, CancellationToken ct)
    {
        // Lọc quyền TRƯỚC khi tính độ tương đồng. Truy hồi trên toàn bộ rồi mới lọc là sai cả về bảo mật lẫn chất lượng:
        // các đoạn liên quan nhất có thể đã bị note không được phép đọc chiếm chỗ trong topK.
        var readableNoteIds = await accessPolicy.ListContentReadableNoteIdsAsync(currentUser.UserId, ct);
        if (readableNoteIds.Count == 0)
        {
            return NotEnoughContext();
        }

        var questionVectors = await llm.EmbedAsync([question], ct);
        var matches = await embeddings.SearchAsync(readableNoteIds, questionVectors[0], TopK, ct);

        var relevantMatches = matches.Where(match => match.Score >= MinRelevanceScore).ToList();
        if (relevantMatches.Count == 0)
        {
            return NotEnoughContext();
        }

        var passages = relevantMatches.Select(match => new ContextPassage(match.NoteTitle, match.ChunkText)).ToList();
        var answer = await llm.AnswerAsync(question, passages, ct);

        // LLM tự nhận không đủ căn cứ thì không gắn trích dẫn — trích dẫn phải là nguồn thật của câu trả lời.
        // Câu báo không tìm thấy dùng chung một câu cố định: model nhỏ đôi khi trả câu này bằng tiếng Anh.
        return answer.HasEnoughContext
            ? new AskNotesOutputDto(answer.Text, HasEnoughContext: true, ToCitations(relevantMatches))
            : NotEnoughContext();
    }

    private static AskNotesOutputDto NotEnoughContext() =>
        new(NotEnoughContextAnswer, HasEnoughContext: false, Citations: []);

    // Chỉ trích những note sát điểm cao nhất; mỗi note một lần, lấy đoạn khớp nhất của note đó.
    private static List<CitationDto> ToCitations(IReadOnlyCollection<EmbeddingMatch> matches)
    {
        var citationFloor = matches.Max(match => match.Score) - CitationScoreMargin;

        return matches
            .Where(match => match.Score >= citationFloor)
            .GroupBy(match => match.NoteId)
            .Select(group => group.MaxBy(match => match.Score)!)
            .OrderByDescending(match => match.Score)
            .Select(match => new CitationDto(match.NoteId, match.NoteTitle, ToExcerpt(match.ChunkText), match.Score))
            .ToList();
    }

    private static string ToExcerpt(string text) =>
        text.Length <= MaxExcerptLength ? text : $"{text[..MaxExcerptLength].TrimEnd()}…";
}

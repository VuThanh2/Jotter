using Jotter.Domain;
using NSubstitute;
using Xunit;

namespace Jotter.Application.UnitTests;

public sealed class LabelCommandTests
{
    private readonly Guid _ownerId = Guid.CreateVersion7();
    private readonly ICurrentUser _currentUser = Substitute.For<ICurrentUser>();
    private readonly ILabelRepository _labels = Substitute.For<ILabelRepository>();
    private readonly INoteRepository _notes = Substitute.For<INoteRepository>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();

    public LabelCommandTests() => _currentUser.UserId.Returns(_ownerId);

    // Kiểm trùng phải dùng tên đã chuẩn hoá: so chuỗi thô "  Work  " sẽ lọt qua và tạo hai nhãn "Work".
    [Fact]
    public async Task Create_ChecksDuplicateAgainstTrimmedName()
    {
        _labels.IsNameTakenAsync(_ownerId, "Work", null, Arg.Any<CancellationToken>()).Returns(true);

        var result = await new CreateLabelCommand(_currentUser, _labels, _unitOfWork).ExecuteAsync(
            new CreateLabelInputDto(Guid.CreateVersion7(), "  Work  "),
            TestData.Ct);

        Assert.Equal(LabelErrors.DuplicateName, result.Error);
        _labels.DidNotReceive().Add(Arg.Any<Label>());
    }

    // Xoá nhãn chỉ gỡ liên kết, không chạm nội dung note, và phải chạm tới mọi note đang gắn nó.
    [Fact]
    public async Task Delete_DetachesLabelFromEveryNote_AndTombstonesLabel()
    {
        var label = GivenLabel(ownerId: _ownerId);
        var otherLabelId = Guid.CreateVersion7();
        var first = TestData.NewNote(_ownerId);
        var second = TestData.NewNote(_ownerId);
        first.SetLabels([label.Id, otherLabelId]);
        second.SetLabels([label.Id]);
        _notes.ListByLabelAsync(label.Id, Arg.Any<CancellationToken>()).Returns(new List<Note> { first, second });

        var result = await DeleteAsync(label.Id);

        Assert.True(result.IsSuccess);
        Assert.True(label.IsDeleted);
        Assert.Equal(new[] { otherLabelId }, first.Labels.Select(link => link.LabelId));
        Assert.Empty(second.Labels);
        Assert.Equal("Nội dung", first.Content);
    }

    [Fact]
    public async Task Delete_LabelOfAnotherUser_IsForbidden_AndTouchesNothing()
    {
        var label = GivenLabel(ownerId: Guid.CreateVersion7());

        var result = await DeleteAsync(label.Id);

        Assert.Equal(AccessErrors.Forbidden, result.Error);
        Assert.False(label.IsDeleted);
        await _notes.DidNotReceive().ListByLabelAsync(Arg.Any<Guid>(), Arg.Any<CancellationToken>());
    }

    private Label GivenLabel(Guid ownerId)
    {
        var label = Label.Create(Guid.CreateVersion7(), ownerId, "Công việc").Value;
        _labels.GetByIdAsync(label.Id, Arg.Any<CancellationToken>()).Returns(label);
        return label;
    }

    private Task<Result> DeleteAsync(Guid labelId) =>
        new DeleteLabelCommand(_currentUser, _labels, _notes, _unitOfWork, new FixedClock(TestData.Now))
            .ExecuteAsync(labelId, TestData.Ct);
}

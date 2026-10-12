using Xunit;

namespace Jotter.Domain.UnitTests;

public sealed class NameValueObjectTests
{
    [Fact]
    public void LabelName_IsTrimmed_AndComparedByValue()
    {
        Assert.Equal(LabelName.Create("Work").Value, LabelName.Create("  Work ").Value);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("   ")]
    public void LabelName_RejectsBlank(string? input)
    {
        Assert.Equal(LabelErrors.NameRequired, LabelName.Create(input).Error);
    }

    [Fact]
    public void LabelName_RejectsTooLong()
    {
        Assert.Equal(LabelErrors.NameTooLong, LabelName.Create(new string('a', LabelName.MaxLength + 1)).Error);
    }

    [Fact]
    public void NoteTitle_KeepsWhitespaceForAutoSave()
    {
        Assert.Equal("Draft ", NoteTitle.Create("Draft ").Value.Value);
    }

    [Fact]
    public void NotePassword_NeverPrintsHash()
    {
        Assert.Equal("***", NotePassword.FromHash("secret-hash").ToString());
    }
}

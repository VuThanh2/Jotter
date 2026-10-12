using System.Text;
using Xunit;

namespace Jotter.Domain.UnitTests;

public sealed class SearchTextTests
{
    [Theory]
    [InlineData("Tiếng Việt", "tieng viet")]
    [InlineData("ĐƯỜNG ĐI", "duong di")]
    [InlineData("  nhiều   khoảng\t\ntrắng  ", "nhieu khoang trang")]
    [InlineData("Ồ, ỨNG DỤNG!", "o, ung dung!")]
    [InlineData("", "")]
    [InlineData(null, "")]
    public void Normalize_LowercasesAndStripsVietnameseDiacritics(string? input, string expected)
    {
        Assert.Equal(expected, SearchText.Normalize(input));
    }

    [Fact]
    public void Normalize_TreatsComposedAndDecomposedInputTheSame()
    {
        const string composed = "Hà Nội";

        Assert.Equal(
            SearchText.Normalize(composed),
            SearchText.Normalize(composed.Normalize(NormalizationForm.FormD)));
    }
}

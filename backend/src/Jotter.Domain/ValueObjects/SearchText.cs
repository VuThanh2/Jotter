using System.Globalization;
using System.Text;

namespace Jotter.Domain;

// Tiêu đề và nội dung chuẩn hoá tách riêng: note đang khoá chỉ được đối chiếu theo tiêu đề,
// và phần nội dung không được đồng bộ xuống thiết bị khi note đang được bảo vệ.
public sealed record SearchText
{
    private SearchText(string title, string content)
    {
        Title = title;
        Content = content;
    }

    public string Title { get; }

    public string Content { get; }

    public static SearchText From(NoteTitle title, NoteContent content) =>
        new(Normalize(title.Value), Normalize(content.Value));

    // PHẢI khớp từng bước với bản Dart:
    // 1. Tách dấu (NFD) rồi bỏ mọi ký tự thuộc nhóm NonSpacingMark  2. đ/Đ → d  3. Hạ chữ thường
    // 4. Gộp mọi chuỗi khoảng trắng thành một dấu cách, bỏ khoảng trắng ở hai đầu
    public static string Normalize(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return string.Empty;
        }

        var decomposed = text.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(decomposed.Length);
        var pendingSpace = false;

        foreach (var ch in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(ch) == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            if (char.IsWhiteSpace(ch))
            {
                pendingSpace = builder.Length > 0;
                continue;
            }

            if (pendingSpace)
            {
                builder.Append(' ');
                pendingSpace = false;
            }

            builder.Append(ch is 'đ' or 'Đ' ? 'd' : char.ToLowerInvariant(ch));
        }

        return builder.ToString();
    }
}

using FluentValidation;
using Jotter.Domain;
using Xunit;

namespace Jotter.Application.UnitTests;

// Chỉ kiểm các rule có logic riêng hoặc từng bị sai; rule một dòng kiểu NotEmpty không cần test lại FluentValidation.
public sealed class ValidatorTests
{
    [Fact]
    public void CreateNote_NothingTyped_IsRejectedAsEmptyNote()
    {
        var input = new CreateNoteInputDto(Guid.CreateVersion7(), "   ", "", ConflictOfNoteId: null);

        Assert.Contains(NoteErrors.EmptyNote.Code, ErrorCodes(new CreateNoteValidator(), input));
    }

    [Fact]
    public void CreateNote_ContentWithoutTitle_IsAccepted()
    {
        var input = new CreateNoteInputDto(Guid.CreateVersion7(), "", "Gõ nội dung trước", ConflictOfNoteId: null);

        Assert.Empty(ErrorCodes(new CreateNoteValidator(), input));
    }

    [Fact]
    public void CreateNote_ConflictCopyPointingAtItself_IsRejected()
    {
        var noteId = Guid.CreateVersion7();
        var input = new CreateNoteInputDto(noteId, "Bản sao", "x", ConflictOfNoteId: noteId);

        Assert.Contains(NoteErrors.InvalidConflictSource.Code, ErrorCodes(new CreateNoteValidator(), input));
    }

    [Fact]
    public void NotePassword_TooShort_IsTooWeak()
    {
        var input = new EnableProtectionInputDto("abc", "abc");

        Assert.Contains(ProtectionErrors.PasswordTooWeak.Code, ErrorCodes(new EnableProtectionValidator(), input));
    }

    // Từng có lỗi: mật khẩu quá dài bị báo "phải có ít nhất N ký tự".
    [Fact]
    public void NotePassword_TooLong_IsNotReportedAsTooWeak()
    {
        var password = new string('a', NotePassword.MaxLength + 1);

        var codes = ErrorCodes(new EnableProtectionValidator(), new EnableProtectionInputDto(password, password));

        Assert.NotEmpty(codes);
        Assert.DoesNotContain(ProtectionErrors.PasswordTooWeak.Code, codes);
    }

    // Từng có lỗi: cùng một ô nhập nhưng Register và UpdateProfile trả mã khác nhau.
    [Fact]
    public void DisplayName_Blank_HasSameCodeOnRegisterAndProfile()
    {
        var register = new RegisterInputDto("an@jotter.app", " ", "P@ssw0rd", "P@ssw0rd");
        var profile = new UpdateProfileInputDto(" ");

        Assert.Contains(UserErrors.DisplayNameRequired.Code, ErrorCodes(new RegisterValidator(), register));
        Assert.Contains(UserErrors.DisplayNameRequired.Code, ErrorCodes(new UpdateProfileValidator(), profile));
    }

    [Theory]
    [InlineData("123456", true)]
    [InlineData("12345", false)]
    [InlineData("1234567", false)]
    [InlineData("12a456", false)]
    public void OtpCode_MustBeExactlySixDigits(string code, bool isValid)
    {
        var codes = ErrorCodes(new ConfirmActivationValidator(), new ConfirmActivationInputDto(code));

        Assert.Equal(isValid, codes.Count == 0);
    }

    // Email gõ sai chỉ làm hỏng người nhận đó (RecipientNotRegistered ở Command), không được làm 400 cả lô.
    [Fact]
    public void ShareNote_MalformedEmail_DoesNotFailWholeBatch()
    {
        var input = new ShareNoteInputDto(
        [
            new ShareRecipientDto("bob@jotter.app", SharePermission.Edit),
            new ShareRecipientDto("bob-thieu-a-cong", SharePermission.ReadOnly)
        ]);

        Assert.Empty(ErrorCodes(new ShareNoteValidator(), input));
    }

    private static List<string> ErrorCodes<T>(AbstractValidator<T> validator, T input) =>
        validator.Validate(input).Errors.Select(error => error.ErrorCode).ToList();
}

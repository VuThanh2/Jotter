namespace Jotter.Application;

public sealed record ChangeNotePasswordInputDto(string CurrentPassword, string NewPassword, string ConfirmPassword);

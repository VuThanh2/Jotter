using FluentValidation;
using Jotter.Domain;

namespace Jotter.Application;

public sealed class CreateNoteValidator : AbstractValidator<CreateNoteInputDto>
{
    public CreateNoteValidator()
    {
        RuleFor(x => x.NoteId).NotEmpty().WithError(NoteErrors.InvalidId);
        RuleFor(x => x.Title).MaximumLength(NoteTitle.MaxLength).WithError(NoteErrors.TitleTooLong);
        RuleFor(x => x.Content).MaximumLength(NoteContent.MaxLength).WithError(NoteErrors.ContentTooLong);

        // Người dùng rời màn hình soạn thảo mà chưa nhập gì thì không được sinh note rỗng.
        RuleFor(x => x.Content)
            .Must((input, content) => !string.IsNullOrWhiteSpace(input.Title) || !string.IsNullOrWhiteSpace(content))
            .WithError(NoteErrors.EmptyNote);

        RuleFor(x => x.ConflictOfNoteId)
            .Must((input, sourceId) => sourceId != Guid.Empty && sourceId != input.NoteId)
            .When(x => x.ConflictOfNoteId is not null)
            .WithError(NoteErrors.InvalidConflictSource);
    }
}

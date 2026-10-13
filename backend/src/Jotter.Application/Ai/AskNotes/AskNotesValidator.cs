using FluentValidation;

namespace Jotter.Application;

public sealed class AskNotesValidator : AbstractValidator<AskNotesInputDto>
{
    public const int MaxQuestionLength = 1_000;

    public AskNotesValidator()
    {
        RuleFor(x => x.Question).NotEmpty().MaximumLength(MaxQuestionLength);
    }
}

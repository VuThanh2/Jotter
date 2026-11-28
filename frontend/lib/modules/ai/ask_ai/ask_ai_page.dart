import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/modules/ai/ask_ai/ask_ai_api.dart';
import 'package:jotter/modules/ai/ask_ai/ask_ai_cubit.dart';
import 'package:jotter/modules/ai/ask_ai/ask_ai_state.dart';
import 'package:jotter/modules/ai/ask_ai/citation_chip.dart';
import 'package:jotter/shared/lib/ai_text.dart';
import 'package:jotter/shared/widgets/page_shortcuts.dart';
import 'package:jotter/shared/widgets/state_views.dart';

class AskAiPage extends StatelessWidget {
  const AskAiPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) =>
        AskAiCubit(AskAiApi(context.read<ApiNoteRepository>())),
    child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          // Wide windows keep a guide column beside the conversation
          // instead of wide empty margins.
          builder: (context, constraints) => constraints.maxWidth >= 1080
              ? Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _AskAiView()),
                        SizedBox(
                          width: 300,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(0, 32, 32, 32),
                            child: _AskGuide(),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: const _AskAiView(),
                  ),
                ),
        ),
      ),
    ),
  );
}

class _AskAiView extends StatefulWidget {
  const _AskAiView();

  @override
  State<_AskAiView> createState() => _AskAiViewState();
}

class _AskAiViewState extends State<_AskAiView> {
  static const _suggestions = [
    'What did I plan for this week?',
    'Summarize my ideas about the project',
    'Which notes mention a deadline?',
  ];

  final _form = GlobalKey<FormState>();
  final _question = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _question.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _ask() {
    if (!_form.currentState!.validate()) return;
    // Touch: get the soft keyboard off the answer. Keyboard: keep the place,
    // so Tab moves on to the sources.
    if (FocusManager.instance.highlightMode == FocusHighlightMode.touch) {
      FocusScope.of(context).unfocus();
    }
    context.read<AskAiCubit>().ask(_question.text);
  }

  /// Fills the question in, leaving the user to adjust it before asking.
  void _suggest(String question) {
    _question.value = TextEditingValue(
      text: question,
      selection: TextSelection.collapsed(offset: question.length),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return PageShortcuts(
      autofocus: true,
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _ask,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _ask,
      },
      child: BlocBuilder<AskAiCubit, AskAiState>(
        builder: (context, state) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 16 : 32,
            narrow ? 20 : 32,
            narrow ? 16 : 32,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Hero(),
              const SizedBox(height: 22),
              _composer(context, state),
              AnimatedSize(
                duration: JotterMotion.medium,
                curve: JotterMotion.curve,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.answer == null &&
                        !state.asking &&
                        state.error == null)
                      _SuggestionList(
                        suggestions: _suggestions,
                        onPick: _suggest,
                      ),
                    if (state.asking) const _Thinking(),
                    if (state.error != null) ...[
                      const SizedBox(height: 18),
                      MessageStrip(state.error!, error: true),
                    ],
                    if (state.answer != null && !state.asking)
                      _AnswerCard(state: state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer(BuildContext context, AskAiState state) {
    final palette = context.jotterColors;
    final focused = _focus.hasFocus;
    InputBorder none() => InputBorder.none;
    return AnimatedContainer(
      duration: JotterMotion.fast,
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? palette.accent : palette.line,
          width: focused ? 1.6 : 1,
        ),
        boxShadow: focused ? palette.softShadow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _form,
            child: TextFormField(
              key: const Key('ask-notes-question'),
              controller: _question,
              focusNode: _focus,
              // Read-only rather than disabled keeps keyboard focus here.
              readOnly: state.asking,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              style: const TextStyle(fontSize: 15, height: 1.5),
              decoration: InputDecoration(
                hintText: 'What did I decide about the March offsite?',
                filled: false,
                border: none(),
                enabledBorder: none(),
                focusedBorder: none(),
                errorBorder: none(),
                focusedErrorBorder: none(),
                disabledBorder: none(),
                contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                counterStyle: TextStyle(fontSize: 11.5, color: palette.muted),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Type a question first.'
                  : null,
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 10),
              Icon(Icons.lock_outline_rounded, size: 14, color: palette.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _shortcutHint ?? 'Only notes you can open',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('ask-notes-submit'),
                onPressed: state.asking ? null : _ask,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: state.asking
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 18),
                label: Text(state.asking ? 'Asking…' : 'Ask'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.accent,
                Color.lerp(palette.accent, const Color(0xFF8A5CC2), .55)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: palette.accent.withValues(alpha: .3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ask your notes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 3),
              Text(
                'Answers come only from notes you can open, with links to '
                'each source.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final muted = context.jotterColors.muted;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRY ASKING',
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in suggestions)
                ActionChip(
                  avatar: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 15,
                    color: muted,
                  ),
                  label: Text(suggestion),
                  onPressed: () => onPick(suggestion),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: EntranceTransition(
        duration: JotterMotion.medium,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.accentSoft.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: palette.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Reading your notes…',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(2)),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.state});

  final AskAiState state;

  @override
  Widget build(BuildContext context) {
    final answer = state.answer!;
    final palette = context.jotterColors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: EntranceTransition(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: palette.accent, width: 3),
                  ),
                ),
                child: Text(state.question!, style: text.titleMedium),
              ),
              const SizedBox(height: 16),
              if (!answer.hasEnoughContext) ...[
                const MessageStrip(
                  'Your notes don’t say enough about this to answer it reliably.',
                  tone: JotterTone.warning,
                  icon: Icons.search_off_rounded,
                ),
                const SizedBox(height: 12),
              ],
              // With nothing to go on, the server's fixed reply only repeats
              // the notice above, and not in the app's language.
              if (answer.hasEnoughContext || answer.citations.isNotEmpty)
                Semantics(
                  liveRegion: true,
                  child: SelectableText(
                    readableAiText(answer.answer),
                    style: text.bodyLarge,
                  ),
                ),
              if (answer.citations.isNotEmpty) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 15,
                      color: palette.muted,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Sources · ${answer.citations.length}',
                      style: text.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final citation in answer.citations)
                  CitationChip(
                    citation: citation,
                    onOpen: () => context.push(AppRoutes.note(citation.noteId)),
                  ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Written by AI. Open the sources to check the details.',
                      style: TextStyle(fontSize: 12.5, color: palette.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phones are used by touch, where a keyboard shortcut is only noise.
String? get _shortcutHint => switch (defaultTargetPlatform) {
  TargetPlatform.android || TargetPlatform.iOS => null,
  TargetPlatform.macOS => '⌘ + Enter to ask',
  _ => 'Ctrl + Enter to ask',
};

/// How Ask AI works, for the side column on wide screens.
class _AskGuide extends StatelessWidget {
  const _AskGuide();

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final steps = [
      (
        Icons.search_rounded,
        'Finds the notes',
        'Your question is matched against notes you can open, including '
            'ones shared with you.',
      ),
      (
        Icons.auto_awesome_outlined,
        'Writes an answer',
        'The answer uses only what those notes say, nothing from the web.',
      ),
      (
        Icons.link_rounded,
        'Shows its sources',
        'Every answer links back to the notes it came from, so you can '
            'check them.',
      ),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW IT WORKS',
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 14),
          for (final (index, (icon, title, body)) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: index == 1 ? palette.accentSoft : palette.selected,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 17,
                      color: index == 1 ? palette.accent : palette.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

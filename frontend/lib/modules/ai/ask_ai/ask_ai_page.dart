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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: const _AskAiView(),
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
  final _form = GlobalKey<FormState>();
  final _question = TextEditingController();

  @override
  void dispose() {
    _question.dispose();
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

  @override
  Widget build(BuildContext context) {
    final muted = context.jotterColors.muted;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return PageShortcuts(
      autofocus: true,
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _ask,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _ask,
      },
      child: BlocBuilder<AskAiCubit, AskAiState>(
        builder: (context, state) => SingleChildScrollView(
          padding: EdgeInsets.all(narrow ? 20 : 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ask your notes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Answers come only from notes you can open, with links to '
                'each source.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 20),
              Form(
                key: _form,
                child: TextFormField(
                  key: const Key('ask-notes-question'),
                  controller: _question,
                  // Read-only rather than disabled keeps keyboard focus here.
                  readOnly: state.asking,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: 'Your question',
                    hintText: 'What did I decide about the March offsite?',
                    helperText: _shortcutHint,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Type a question first.'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('ask-notes-submit'),
                  onPressed: state.asking ? null : _ask,
                  child: Text(state.asking ? 'Looking through notes…' : 'Ask'),
                ),
              ),
              if (state.asking)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
              if (state.error != null) ...[
                const SizedBox(height: 18),
                MessageStrip(state.error!, error: true),
              ],
              if (state.answer != null) ..._answer(context, state),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _answer(BuildContext context, AskAiState state) {
    final answer = state.answer!;
    final muted = context.jotterColors.muted;
    return [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Divider(height: 1),
      ),
      Text(state.question!, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      if (!answer.hasEnoughContext) ...[
        const MessageStrip(
          'Your notes don’t say enough about this to answer it reliably.',
        ),
        const SizedBox(height: 12),
      ],
      // With nothing to go on, the server's fixed reply only repeats the
      // notice above, and not in the app's language.
      if (answer.hasEnoughContext || answer.citations.isNotEmpty)
        Semantics(
          liveRegion: true,
          child: SelectableText(
            readableAiText(answer.answer),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      if (answer.citations.isNotEmpty) ...[
        const SizedBox(height: 22),
        Text('Sources', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final citation in answer.citations)
          CitationChip(
            citation: citation,
            onOpen: () => context.push(AppRoutes.note(citation.noteId)),
          ),
      ],
      const SizedBox(height: 14),
      Text(
        'Written by AI. Open the sources to check the details.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
    ];
  }
}

/// Phones are used by touch, where a keyboard shortcut is only noise.
String? get _shortcutHint => switch (defaultTargetPlatform) {
  TargetPlatform.android || TargetPlatform.iOS => null,
  TargetPlatform.macOS => '⌘ + Enter to ask',
  _ => 'Ctrl + Enter to ask',
};

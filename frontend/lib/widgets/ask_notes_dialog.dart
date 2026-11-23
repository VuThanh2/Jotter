import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_note_repository.dart';
import '../data/note_features_api.dart';
import '../data/note_repository.dart';
import '../models/note_features.dart';

Future<void> showAskNotesDialog(
  BuildContext context, {
  required ApiNoteRepository repository,
  required Future<void> Function(String) onOpenNote,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _AskNotesDialog(repository: repository, onOpenNote: onOpenNote),
);

class _AskNotesDialog extends StatefulWidget {
  const _AskNotesDialog({required this.repository, required this.onOpenNote});
  final ApiNoteRepository repository;
  final Future<void> Function(String) onOpenNote;
  @override
  State<_AskNotesDialog> createState() => _AskNotesDialogState();
}

class _AskNotesDialogState extends State<_AskNotesDialog> {
  final _question = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _asking = false;
  int _generation = 0;
  NotesAnswer? _answer;
  String? _error;
  String? _answeredQuestion;

  @override
  void dispose() {
    _generation++;
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (_asking || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final question = _question.text.trim();
    final generation = ++_generation;
    setState(() {
      _asking = true;
      _error = null;
    });
    try {
      final answer = await widget.repository.askNotes(question);
      if (!mounted || generation != _generation) return;
      setState(() {
        _answer = answer;
        _answeredQuestion = question;
      });
    } catch (error) {
      if (mounted && generation == _generation)
        setState(
          () => _error = error is RepositoryException
              ? error.message
              : 'Could not get an answer. Please try again.',
        );
    } finally {
      if (mounted && generation == _generation) setState(() => _asking = false);
    }
  }

  Future<void> _openCitation(String noteId) async {
    final onOpenNote = widget.onOpenNote;
    Navigator.pop(context);
    await onOpenNote(noteId);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _ask,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _ask,
      },
      child: Dialog(
        insetPadding: EdgeInsets.all(narrow ? 10 : 28),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 860),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 10, 18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 22,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ask your notes',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close Ask your notes',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(narrow ? 20 : 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'A thought you can’t quite find?',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ask a question about your notes. Answers include sources you can open and check.',
                        ),
                        const SizedBox(height: 20),
                        Form(
                          key: _form,
                          child: TextFormField(
                            key: const Key('ask-notes-question'),
                            controller: _question,
                            enabled: !_asking,
                            minLines: 2,
                            maxLines: 5,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              labelText: 'Your question',
                              hintText:
                                  'What are the next steps for my project?',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter a question about your notes.'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            key: const Key('ask-notes-submit'),
                            onPressed: _asking ? null : _ask,
                            icon: _asking
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.arrow_upward, size: 18),
                            label: Text(
                              _asking
                                  ? 'Finding the thread…'
                                  : 'Ask your notes',
                            ),
                          ),
                        ),
                        if (_asking)
                          const Padding(
                            padding: EdgeInsets.only(top: 14),
                            child: Text(
                              'This may take a little while. You can close this window while the request finishes.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_answer != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Divider(),
                          ),
                          Text(
                            _answeredQuestion!,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          if (!_answer!.hasEnoughContext)
                            Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: .3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'There isn’t enough relevant context in your notes for a confident answer. Try a more specific question or add more notes.',
                              ),
                            ),
                          Semantics(
                            liveRegion: true,
                            child: SelectableText(
                              _answer!.answer,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          if (_answer!.citations.isNotEmpty) ...[
                            const SizedBox(height: 26),
                            Text(
                              'From your notes',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            for (final citation in _answer!.citations)
                              Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _openCitation(citation.noteId),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.notes_rounded,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                citation.title.isEmpty
                                                    ? 'Untitled note'
                                                    : citation.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.open_in_new,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          citation.excerpt,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 18),
                          Text(
                            'AI can make mistakes. The cited notes are the source of truth.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

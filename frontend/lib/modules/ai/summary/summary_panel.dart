import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/modules/ai/summary/summary_api.dart';
import 'package:jotter/modules/ai/summary/summary_cubit.dart';
import 'package:jotter/modules/ai/summary/summary_state.dart';
import 'package:jotter/shared/lib/ai_text.dart';
import 'package:jotter/shared/widgets/modal_panel.dart';
import 'package:jotter/shared/widgets/note_card.dart';
import 'package:jotter/shared/widgets/state_views.dart';

Future<void> showSummaryPanel(
  BuildContext context, {
  required String noteId,
  required String noteTitle,
}) {
  final api = SummaryApi(context.read<ApiNoteRepository>());
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => SummaryCubit(api, noteId: noteId)..load(),
      child: _SummaryPanel(noteTitle: noteTitle),
    ),
  );
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.noteTitle});

  final String noteTitle;

  @override
  Widget build(BuildContext context) => BlocBuilder<SummaryCubit, SummaryState>(
    builder: (context, state) {
      final cubit = context.read<SummaryCubit>();
      final muted = context.jotterColors.muted;
      return ModalPanel(
        title: 'Summary',
        subtitle: noteTitle.isEmpty ? 'Untitled note' : noteTitle,
        busy: state.generating,
        footer: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              key: const Key('summary-generate'),
              onPressed: state.status == SummaryStatus.ready
                  ? cubit.generate
                  : null,
              child: Text(
                state.savedAt == null ? 'Summarize' : 'Summarize again',
              ),
            ),
            if (state.generating)
              OutlinedButton(onPressed: cubit.stop, child: const Text('Stop')),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.error != null) ...[
              MessageStrip(state.error!, error: true),
              const SizedBox(height: 14),
            ],
            if (state.status == SummaryStatus.loading)
              const LoadingView(label: 'Loading summary')
            else if (state.text.isEmpty)
              Text(
                state.generating
                    ? 'Reading the note…'
                    : 'No summary yet. It will cover the main points of '
                          'this note.',
                style: TextStyle(color: muted),
              )
            else
              Semantics(
                liveRegion: true,
                child: SelectableText(
                  readableAiText(state.text),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            const SizedBox(height: 16),
            Text(_caption(state), style: TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      );
    },
  );

  static String _caption(SummaryState state) {
    if (state.isPartial) {
      return 'Stopped before it finished, so it was not saved.';
    }
    final saved = state.savedAt == null
        ? ''
        : 'Last saved: ${relativeDate(state.savedAt!)}. ';
    return '${saved}Written by AI from this note; check the note for details.';
  }
}

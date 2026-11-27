import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/models/sync_status.dart';
import 'package:jotter/modules/sync/sync_status/sync_sheet_cubit.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_state.dart';
import 'package:jotter/platform/file_transfer.dart';
import 'package:jotter/shared/widgets/confirm_dialog.dart';
import 'package:jotter/shared/widgets/modal_panel.dart';
import 'package:jotter/shared/widgets/state_views.dart';

Future<void> showSyncStatusSheet(BuildContext context) {
  final workspace = context.read<OfflineNoteRepository>();
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => SyncSheetCubit(workspace),
      child: const _SyncStatusSheet(),
    ),
  );
}

class _SyncStatusSheet extends StatelessWidget {
  const _SyncStatusSheet();

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<SyncSheetCubit, SyncSheetState>(
    builder: (context, state) {
      final cubit = context.read<SyncSheetCubit>();
      final muted = context.jotterColors.muted;
      final status = state.status;
      return ModalPanel(
        title: 'Sync',
        busy: state.busy || status.isSyncing,
        footer: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: state.busy || status.isSyncing ? null : cubit.syncNow,
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Sync now'),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(status.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              status.realtimeConnected
                  ? 'Live updates are on.'
                  : 'Live updates will reconnect on their own.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 14),
            Text(
              'Your own notes without a password can be edited offline. '
              'Changes wait here and sync when you are back online. '
              'Protected and shared notes need a connection.',
              style: TextStyle(color: muted),
            ),
            // Listed conflicts already explain the workspace's own error.
            for (final message in [
              if (status.conflictCount == 0) status.error,
              state.error,
            ])
              if (message != null) ...[
                const SizedBox(height: 14),
                MessageStrip(message, error: true),
              ],
            const SizedBox(height: 20),
            if (state.changes.isEmpty)
              const Text('Nothing waiting to sync.')
            else
              for (final change in state.changes)
                _PendingChangeCard(change: change, busy: state.busy),
          ],
        ),
      );
    },
  );
}

class _PendingChangeCard extends StatelessWidget {
  const _PendingChangeCard({required this.change, required this.busy});

  final PendingWorkspaceChange change;
  final bool busy;

  Future<void> _discard(BuildContext context) async {
    final cubit = context.read<SyncSheetCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard this change?',
      message:
          'Edits that have not synced will be lost. Review the draft first '
          'if you still need it.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep',
    );
    if (confirmed) await cubit.discard(change.id);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SyncSheetCubit>();
    final draft = cubit.draftOf(change.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              change.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              change.error ?? 'Waiting to sync',
              style: TextStyle(fontSize: 13, color: context.jotterColors.muted),
            ),
            Wrap(
              spacing: 4,
              children: [
                if (draft != null)
                  TextButton(
                    onPressed: busy ? null : () => _showDraft(context, draft),
                    child: const Text('Review draft'),
                  ),
                if (change.isConflict)
                  TextButton(
                    onPressed: busy ? null : () => cubit.saveAsCopy(change.id),
                    child: const Text('Save as a copy'),
                  ),
                if (change.isBlocked && change.code != 'ProtectedDraft')
                  TextButton(
                    onPressed: busy ? null : () => cubit.retry(change.id),
                    child: const Text('Retry'),
                  ),
                TextButton(
                  onPressed: busy ? null : () => _discard(context),
                  child: const Text('Discard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showDraft(BuildContext context, JotterNote draft) {
  final text = '${draft.title}\n\n${draft.content}';
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(draft.title.isEmpty ? 'Unsaved draft' : draft.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(child: SelectableText(draft.content)),
      ),
      actions: [
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: text)),
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => saveBytes(
            Uint8List.fromList(utf8.encode(text)),
            'jotter-draft.txt',
            mimeType: 'text/plain',
          ),
          child: const Text('Export'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

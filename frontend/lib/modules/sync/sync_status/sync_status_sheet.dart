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
  return showAdaptivePanel<void>(
    context,
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
        icon: Icons.cloud_sync_outlined,
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
            _StatusHeader(status: status),
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
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color: context.jotterColors.tone(JotterTone.success).icon,
                  ),
                  const SizedBox(width: 8),
                  const Text('Nothing waiting to sync.'),
                ],
              )
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
      icon: Icons.delete_sweep_outlined,
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
            Row(
              children: [
                Icon(
                  change.isConflict
                      ? Icons.call_split_rounded
                      : change.error != null
                      ? Icons.error_outline_rounded
                      : Icons.schedule_rounded,
                  size: 17,
                  color: change.error != null || change.isConflict
                      ? Theme.of(context).colorScheme.error
                      : context.jotterColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    change.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 25),
              child: Text(
                change.error ?? 'Waiting to sync',
                style: TextStyle(
                  fontSize: 13.5,
                  color: context.jotterColors.muted,
                ),
              ),
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
  return showJotterDialog<void>(
    context,
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

/// The overall state as a coloured badge with live-update status below.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status});

  final WorkspaceSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final (tone, icon) = status.conflictCount > 0 || status.error != null
        ? (JotterTone.error, Icons.sync_problem_rounded)
        : status.isOffline
        ? (JotterTone.warning, Icons.cloud_off_outlined)
        : status.pendingCount > 0 || status.isSyncing
        ? (JotterTone.info, Icons.cloud_upload_outlined)
        : (JotterTone.success, Icons.cloud_done_outlined);
    final colors = palette.tone(tone);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: colors.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: colors.foreground),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: JotterMotion.medium,
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: status.realtimeConnected
                            ? palette.tone(JotterTone.success).icon
                            : palette.muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        status.realtimeConnected
                            ? 'Live updates are on.'
                            : 'Live updates will reconnect on their own.',
                        style: TextStyle(fontSize: 12.5, color: palette.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/offline_note_repository.dart';
import '../models/sync_status.dart';
import '../platform/file_transfer.dart';

Future<void> showSyncStatusDialog(
  BuildContext context,
  OfflineNoteRepository repository,
) =>
    showDialog<void>(context: context, builder: (_) => _SyncDialog(repository));

class _SyncDialog extends StatefulWidget {
  const _SyncDialog(this.repository);
  final OfflineNoteRepository repository;
  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  String? _error;
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(PendingWorkspaceChange change) async {
    final draft = widget.repository.pendingDraft(change.id);
    if (draft == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(draft.title.isEmpty ? 'Unsaved draft' : draft.title),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(child: SelectableText(draft.content)),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(
              ClipboardData(text: '${draft.title}\n\n${draft.content}'),
            ),
            child: const Text('Copy draft'),
          ),
          TextButton(
            onPressed: () async {
              await saveBytes(
                Uint8List.fromList(
                  utf8.encode('${draft.title}\n\n${draft.content}'),
                ),
                'jotter-draft.txt',
                mimeType: 'text/plain',
              );
            },
            child: const Text('Export draft'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<WorkspaceSyncStatus>(
    valueListenable: widget.repository.syncStatus,
    builder: (context, status, _) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Saved here. Synced everywhere.',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close sync status',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status.realtimeConnected
                            ? 'Live updates connected'
                            : 'Live updates reconnect automatically',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Unprotected notes you own can be read and edited offline during this session. Their pending changes survive app restarts and resume after you sign in to this account. Protected and shared note content is not stored on this device.',
                      ),
                      if (status.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            status.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (widget.repository.pendingChanges.isEmpty)
                        const Text('No pending changes. You’re all caught up.')
                      else
                        for (final change in widget.repository.pendingChanges)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    change.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    change.error ?? 'Waiting to sync',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  if (change.code == 'ProtectedDraft')
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'This note became protected elsewhere. Its pending draft is kept only in memory. Review or export it before closing the app.',
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (widget.repository.pendingDraft(
                                            change.id,
                                          ) !=
                                          null)
                                        TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _review(change),
                                          child: const Text('Review draft'),
                                        ),
                                      if (change.isConflict)
                                        TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _run(() async {
                                                  await widget.repository
                                                      .recoverConflictAsCopy(
                                                        change.id,
                                                      );
                                                }),
                                          child: const Text(
                                            'Save conflict copy',
                                          ),
                                        ),
                                      if (change.isBlocked &&
                                          change.code != 'ProtectedDraft')
                                        TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _run(() async {
                                                  await widget.repository
                                                      .retryPending(change.id);
                                                }),
                                          child: const Text('Retry'),
                                        ),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () async {
                                                final discard =
                                                    await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) =>
                                                          AlertDialog(
                                                            title: const Text(
                                                              'Discard this pending change?',
                                                            ),
                                                            content: const Text(
                                                              'Any unsynced edits in this change will be lost. Review or export the draft first if you need it.',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                      false,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Keep change',
                                                                    ),
                                                              ),
                                                              FilledButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                      true,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Discard',
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                    );
                                                if (discard == true)
                                                  await _run(
                                                    () => widget.repository
                                                        .discardPending(
                                                          change.id,
                                                        ),
                                                  );
                                              },
                                        child: const Text('Discard'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: FilledButton.icon(
                  onPressed: _busy || status.isSyncing
                      ? null
                      : () => _run(widget.repository.synchronize),
                  icon: const Icon(Icons.sync),
                  label: Text(_busy ? 'Working…' : 'Sync now'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

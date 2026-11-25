import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/models/sync_status.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_cubit.dart';
import 'package:jotter/widgets/sync_status_dialog.dart';

/// Hidden while everything is synced; otherwise explains what is pending.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SyncStatusCubit, WorkspaceSyncStatus>(
        builder: (context, status) {
          final (IconData icon, String label, bool error)? look =
              switch (status) {
                WorkspaceSyncStatus(conflictCount: > 0) => (
                  Icons.sync_problem_rounded,
                  'Sync failed',
                  true,
                ),
                WorkspaceSyncStatus(isOffline: true) => (
                  Icons.cloud_off_outlined,
                  status.pendingCount > 0
                      ? 'Offline · ${status.pendingCount} waiting'
                      : 'Offline',
                  false,
                ),
                WorkspaceSyncStatus(pendingCount: > 0) => (
                  Icons.cloud_upload_outlined,
                  '${status.pendingCount} waiting to sync',
                  false,
                ),
                _ => null,
              };
          if (look == null) return const SizedBox.shrink();
          final (icon, label, error) = look;
          final color = error
              ? Theme.of(context).colorScheme.error
              : context.jotterColors.muted;
          return Tooltip(
            message: status.label,
            child: TextButton.icon(
              key: const Key('sync-status'),
              onPressed: () => showSyncStatusDialog(
                context,
                context.read<OfflineNoteRepository>(),
              ),
              icon: Icon(icon, size: 17, color: color),
              label: Text(label, style: TextStyle(fontSize: 12, color: color)),
            ),
          );
        },
      );
}

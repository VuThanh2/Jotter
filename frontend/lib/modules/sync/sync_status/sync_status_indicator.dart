import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/sync_status.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_cubit.dart';
import 'package:jotter/modules/sync/sync_status/sync_status_sheet.dart';

/// Hidden while everything is synced; otherwise explains what is pending.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key, this.compact = false});

  /// Icon only, for the narrow navigation rail.
  final bool compact;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SyncStatusCubit, WorkspaceSyncStatus>(
        builder: (context, status) {
          final (IconData icon, String label, JotterTone tone)? look =
              switch (status) {
                WorkspaceSyncStatus(conflictCount: > 0) => (
                  Icons.sync_problem_rounded,
                  'Sync failed',
                  JotterTone.error,
                ),
                WorkspaceSyncStatus(isOffline: true) => (
                  Icons.cloud_off_outlined,
                  status.pendingCount > 0
                      ? 'Offline · ${status.pendingCount} waiting'
                      : 'Offline',
                  JotterTone.warning,
                ),
                WorkspaceSyncStatus(pendingCount: > 0) => (
                  Icons.cloud_upload_outlined,
                  '${status.pendingCount} waiting to sync',
                  JotterTone.info,
                ),
                _ => null,
              };
          return AnimatedSwitcher(
            duration: JotterMotion.medium,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axis: Axis.horizontal,
                child: child,
              ),
            ),
            child: look == null
                ? const SizedBox.shrink()
                : _Pill(
                    key: ValueKey(look.$2),
                    icon: look.$1,
                    label: look.$2,
                    tone: look.$3,
                    tooltip: status.label,
                    compact: compact,
                  ),
          );
        },
      );
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
    required this.tooltip,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final JotterTone tone;
  final String tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.jotterColors.tone(tone);
    if (compact) {
      return IconButton(
        key: const Key('sync-status'),
        tooltip: '$label · $tooltip',
        onPressed: () => showSyncStatusSheet(context),
        style: IconButton.styleFrom(backgroundColor: colors.background),
        icon: Icon(icon, size: 19, color: colors.icon),
      );
    }
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextButton.icon(
          key: const Key('sync-status'),
          onPressed: () => showSyncStatusSheet(context),
          style: TextButton.styleFrom(
            backgroundColor: colors.background,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors.border),
            ),
          ),
          icon: Icon(icon, size: 16, color: colors.icon),
          label: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

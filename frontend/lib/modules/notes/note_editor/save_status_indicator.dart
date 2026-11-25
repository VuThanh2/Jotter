import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/modules/notes/note_editor/note_editor_state.dart';

class SaveStatusIndicator extends StatelessWidget {
  const SaveStatusIndicator({
    super.key,
    required this.status,
    this.error,
    this.onRetry,
  });

  final SaveStatus status;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final muted = context.jotterColors.muted;
    final failedColor = Theme.of(context).colorScheme.error;
    final (IconData? icon, String label, Color color) = switch (status) {
      SaveStatus.idle => (null, '', muted),
      SaveStatus.pending ||
      SaveStatus.saving => (Icons.sync_rounded, 'Saving…', muted),
      SaveStatus.saved => (Icons.cloud_done_outlined, 'Saved', muted),
      SaveStatus.savedOffline => (
        Icons.cloud_off_outlined,
        'Saved on this device',
        muted,
      ),
      SaveStatus.failed => (
        Icons.error_outline_rounded,
        'Not saved',
        failedColor,
      ),
    };
    if (icon == null) return const SizedBox.shrink();
    final indicator = Semantics(
      liveRegion: true,
      label: status == SaveStatus.failed && error != null
          ? '$label. $error'
          : label,
      excludeSemantics: true,
      child: Row(
        key: const Key('save-status'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(message: error ?? label, child: indicator),
        if (status == SaveStatus.failed && onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

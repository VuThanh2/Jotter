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
    final palette = context.jotterColors;
    final failedColor = Theme.of(context).colorScheme.error;
    final (IconData? icon, String label, Color color) = switch (status) {
      SaveStatus.idle => (null, '', palette.muted),
      SaveStatus.pending ||
      SaveStatus.saving => (Icons.sync_rounded, 'Saving…', palette.muted),
      SaveStatus.saved => (
        Icons.cloud_done_outlined,
        'Saved',
        palette.dark ? const Color(0xFF8FCB94) : const Color(0xFF3F8A4A),
      ),
      SaveStatus.savedOffline => (
        Icons.cloud_off_outlined,
        'Saved on this device',
        palette.muted,
      ),
      SaveStatus.failed => (
        Icons.error_outline_rounded,
        'Not saved',
        failedColor,
      ),
    };
    // Pending and saving look the same, so they share one key and the pill
    // does not flicker between them.
    final key = status == SaveStatus.pending ? SaveStatus.saving : status;
    final Widget child;
    if (icon == null) {
      child = const SizedBox.shrink(key: ValueKey(SaveStatus.idle));
    } else {
      final indicator = Semantics(
        liveRegion: true,
        label: status == SaveStatus.failed && error != null
            ? '$label. $error'
            : label,
        excludeSemantics: true,
        child: Container(
          key: const Key('save-status'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: palette.dark ? .14 : .09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      child = Row(
        key: ValueKey(key),
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Tooltip(message: error ?? label, child: indicator),
          ),
          if (status == SaveStatus.failed && onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: JotterMotion.medium,
      switchInCurve: JotterMotion.curve,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .92, end: 1).animate(animation),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

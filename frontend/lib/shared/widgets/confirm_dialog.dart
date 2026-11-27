import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/modal_panel.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = true,
  IconData? icon,
}) async {
  final confirmed = await showJotterDialog<bool>(
    context,
    builder: (context) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon:
          icon ??
          (destructive
              ? Icons.delete_outline_rounded
              : Icons.help_outline_rounded),
    ),
  );
  return confirmed ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.jotterColors;
    // Phones stack full-width buttons within thumb reach; wider screens keep
    // the familiar right-aligned pair.
    final stacked = context.isCompact;
    final confirm = FilledButton(
      style: destructive
          ? FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            )
          : null,
      onPressed: () => Navigator.pop(context, true),
      child: Text(confirmLabel),
    );
    final cancel = stacked
        ? OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          )
        : TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          );
    final badge = destructive
        ? (scheme.error.withValues(alpha: .1), scheme.error)
        : (palette.accentSoft, palette.accent);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: stacked ? 20 : 40,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: badge.$1,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: badge.$2, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: stacked ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    textAlign: stacked ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: palette.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (stacked)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [confirm, const SizedBox(height: 8), cancel],
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [cancel, confirm],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

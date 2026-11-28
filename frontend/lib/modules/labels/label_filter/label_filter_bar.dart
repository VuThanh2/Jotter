import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/jotter_label.dart';

/// Multi-select label chips. A note matches when it has any selected label.
class LabelFilterBar extends StatelessWidget {
  const LabelFilterBar({
    super.key,
    required this.labels,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  final List<JotterLabel> labels;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final muted = context.jotterColors.muted;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label.name),
                avatar: selected.contains(label.id)
                    ? null
                    : Icon(Icons.label_outline_rounded, size: 16, color: muted),
                selected: selected.contains(label.id),
                onSelected: (_) => onToggle(label.id),
              ),
            ),
          AnimatedSize(
            duration: JotterMotion.fast,
            curve: JotterMotion.curve,
            child: selected.isEmpty
                ? const SizedBox.shrink()
                : TextButton.icon(
                    key: const Key('clear-label-filter'),
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Clear'),
                  ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: muted),
            onPressed: () => context.push(AppRoutes.labels),
            icon: Icon(
              labels.isEmpty ? Icons.new_label_outlined : Icons.tune_rounded,
              size: 16,
            ),
            label: Text(labels.isEmpty ? 'Add labels' : 'Manage'),
          ),
        ],
      ),
    );
  }
}

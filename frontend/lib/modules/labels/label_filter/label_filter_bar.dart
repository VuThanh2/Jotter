import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/routes/app_routes.dart';
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
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final label in labels)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label.name),
              selected: selected.contains(label.id),
              onSelected: (_) => onToggle(label.id),
            ),
          ),
        if (selected.isNotEmpty)
          TextButton.icon(
            key: const Key('clear-label-filter'),
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Clear'),
          ),
        TextButton.icon(
          onPressed: () => context.push(AppRoutes.labels),
          icon: const Icon(Icons.tune_rounded, size: 16),
          label: Text(labels.isEmpty ? 'Add labels' : 'Manage'),
        ),
      ],
    ),
  );
}

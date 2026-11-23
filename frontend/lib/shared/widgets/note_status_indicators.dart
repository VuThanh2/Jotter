import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/jotter_note.dart';

class NoteStatusIndicators extends StatelessWidget {
  const NoteStatusIndicators({super.key, required this.note, this.size = 15});

  final JotterNote note;
  final double size;

  @override
  Widget build(BuildContext context) {
    final muted = context.jotterColors.muted;
    final indicators = [
      if (note.isPinned)
        _Indicator(Icons.push_pin_rounded, 'Pinned', JotterColors.accent),
      if (note.isShared || !note.isOwned)
        _Indicator(
          Icons.people_outline_rounded,
          note.isOwned ? 'Shared with others' : 'Shared with you',
          muted,
        ),
      if (note.isProtected)
        _Indicator(Icons.lock_outline_rounded, 'Password protected', muted),
      if (note.conflictOfNoteId != null)
        _Indicator(Icons.call_split_rounded, 'Conflict copy', muted),
    ];
    if (indicators.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final indicator in indicators)
          Tooltip(
            message: indicator.label,
            child: Semantics(
              label: indicator.label,
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(indicator.icon, size: size, color: indicator.color),
              ),
            ),
          ),
      ],
    );
  }
}

class _Indicator {
  const _Indicator(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;
}

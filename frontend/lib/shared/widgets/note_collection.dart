import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/jotter_note.dart';

/// Lays notes out as a responsive grid or a list.
class NoteCollectionSliver extends StatelessWidget {
  const NoteCollectionSliver({
    super.key,
    required this.notes,
    required this.listMode,
    required this.itemBuilder,
  });

  final List<JotterNote> notes;
  final bool listMode;
  final Widget Function(BuildContext context, JotterNote note) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (listMode) {
      return SliverList.separated(
        itemCount: notes.length,
        itemBuilder: (context, index) => itemBuilder(context, notes[index]),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = width >= 1100
            ? 4
            : width >= 780
            ? 3
            : width >= 460
            ? 2
            : 1;
        return SliverGrid.builder(
          itemCount: notes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: columns == 1 ? 200 : 240,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (context, index) => itemBuilder(context, notes[index]),
        );
      },
    );
  }
}

class NoteSectionHeading extends StatelessWidget {
  const NoteSectionHeading(this.title, {super.key, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Row(
      children: [
        Icon(icon, size: 14, color: context.jotterColors.muted),
        const SizedBox(width: 7),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
            color: context.jotterColors.muted,
          ),
        ),
      ],
    ),
  );
}

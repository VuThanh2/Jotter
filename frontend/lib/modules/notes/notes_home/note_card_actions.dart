import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/jotter_note.dart';

enum NoteCardAction { pin, labels, delete }

/// Owner-only quick actions on a note card.
class NoteCardMenu extends StatelessWidget {
  const NoteCardMenu({super.key, required this.note, required this.onSelected});

  final JotterNote note;
  final ValueChanged<NoteCardAction> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 32,
    child: PopupMenuButton<NoteCardAction>(
      tooltip: 'Note actions',
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_horiz_rounded,
        size: 20,
        color: context.jotterColors.muted,
      ),
      onSelected: onSelected,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: NoteCardAction.pin,
          child: ListTile(
            leading: Icon(
              note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            title: Text(note.isPinned ? 'Unpin' : 'Pin to top'),
          ),
        ),
        const PopupMenuItem(
          value: NoteCardAction.labels,
          child: ListTile(
            leading: Icon(Icons.label_outline_rounded),
            title: Text('Labels'),
          ),
        ),
        PopupMenuItem(
          value: NoteCardAction.delete,
          child: ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ],
    ),
  );
}

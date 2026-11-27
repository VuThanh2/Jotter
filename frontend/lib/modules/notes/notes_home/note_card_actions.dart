import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/modal_panel.dart';

enum NoteCardAction { pin, labels, delete }

/// Phones show a note's actions in a sheet, from the menu button or a long
/// press on the card.
Future<void> showNoteActionSheet(
  BuildContext context,
  JotterNote note,
  ValueChanged<NoteCardAction> onSelected,
) async {
  final action = await showActionSheet<NoteCardAction>(
    context,
    title: note.title.isEmpty ? 'Untitled note' : note.title,
    items: [
      ActionSheetItem(
        value: NoteCardAction.pin,
        icon: note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        label: note.isPinned ? 'Unpin' : 'Pin to top',
        selected: note.isPinned,
      ),
      const ActionSheetItem(
        value: NoteCardAction.labels,
        icon: Icons.label_outline_rounded,
        label: 'Labels',
      ),
      const ActionSheetItem(
        value: NoteCardAction.delete,
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
        destructive: true,
      ),
    ],
  );
  if (action != null) onSelected(action);
}

/// Owner-only quick actions on a note card: a sheet on phones, a popup menu
/// next to the pointer on wider screens.
class NoteCardMenu extends StatelessWidget {
  const NoteCardMenu({super.key, required this.note, required this.onSelected});

  final JotterNote note;
  final ValueChanged<NoteCardAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.more_horiz_rounded,
      size: 20,
      color: context.jotterColors.muted,
    );
    if (context.isCompact) {
      return SizedBox.square(
        dimension: 32,
        child: IconButton(
          tooltip: 'Note actions',
          padding: EdgeInsets.zero,
          onPressed: () => showNoteActionSheet(context, note, onSelected),
          icon: icon,
        ),
      );
    }
    return SizedBox.square(
      dimension: 32,
      child: PopupMenuButton<NoteCardAction>(
        tooltip: 'Note actions',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        icon: icon,
        onSelected: onSelected,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: NoteCardAction.pin,
            child: MenuRow(
              icon: note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              label: note.isPinned ? 'Unpin' : 'Pin to top',
            ),
          ),
          const PopupMenuItem(
            value: NoteCardAction.labels,
            child: MenuRow(icon: Icons.label_outline_rounded, label: 'Labels'),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: NoteCardAction.delete,
            child: MenuRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              destructive: true,
            ),
          ),
        ],
      ),
    );
  }
}

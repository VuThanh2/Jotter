import 'package:flutter/material.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/modal_panel.dart';

enum EditorAction { share, protection, summary, delete }

enum _SheetChoice { labels, attach, share, protection, summary, delete }

/// Note actions in the editor app bar, shown according to the user's access.
/// Wide screens keep the frequent ones as icons and the rest in a popup;
/// phones keep only pin and gather everything else in one sheet, so the bar
/// never runs out of room next to the save status.
class EditorActionBar extends StatelessWidget {
  const EditorActionBar({
    super.key,
    required this.note,
    required this.existsOnServer,
    required this.canEdit,
    required this.onPin,
    required this.onLabels,
    required this.onAttach,
    required this.onAction,
  });

  final JotterNote note;
  final bool existsOnServer;
  final bool canEdit;
  final VoidCallback onPin;
  final VoidCallback onLabels;
  final VoidCallback onAttach;
  final ValueChanged<EditorAction> onAction;

  bool get _owner => note.isOwned;

  Future<void> _openSheet(BuildContext context) async {
    final choice = await showActionSheet<_SheetChoice>(
      context,
      title: note.title.isEmpty ? 'Untitled note' : note.title,
      items: [
        if (_owner)
          const ActionSheetItem(
            value: _SheetChoice.labels,
            icon: Icons.label_outline_rounded,
            label: 'Labels',
          ),
        if (canEdit)
          const ActionSheetItem(
            value: _SheetChoice.attach,
            icon: Icons.attach_file_rounded,
            label: 'Attach files',
          ),
        if (_owner)
          const ActionSheetItem(
            value: _SheetChoice.share,
            icon: Icons.person_add_alt_outlined,
            label: 'Share',
          ),
        if (_owner)
          ActionSheetItem(
            value: _SheetChoice.protection,
            icon: note.isProtected
                ? Icons.lock_rounded
                : Icons.lock_outline_rounded,
            label: 'Password protection',
            selected: note.isProtected,
          ),
        const ActionSheetItem(
          value: _SheetChoice.summary,
          icon: Icons.auto_awesome_outlined,
          label: 'AI summary',
        ),
        if (_owner)
          const ActionSheetItem(
            value: _SheetChoice.delete,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            destructive: true,
          ),
      ],
    );
    switch (choice) {
      case _SheetChoice.labels:
        onLabels();
      case _SheetChoice.attach:
        onAttach();
      case _SheetChoice.share:
        onAction(EditorAction.share);
      case _SheetChoice.protection:
        onAction(EditorAction.protection);
      case _SheetChoice.summary:
        onAction(EditorAction.summary);
      case _SheetChoice.delete:
        onAction(EditorAction.delete);
      case null:
        break;
    }
  }

  Widget _pin() => IconButton(
    key: const Key('editor-pin'),
    tooltip: note.isPinned ? 'Unpin' : 'Pin to top',
    isSelected: note.isPinned,
    onPressed: onPin,
    icon: const Icon(Icons.push_pin_outlined),
    selectedIcon: const Icon(Icons.push_pin),
  );

  Widget _labels() => IconButton(
    key: const Key('editor-labels'),
    tooltip: 'Labels',
    onPressed: onLabels,
    icon: const Icon(Icons.label_outline_rounded),
  );

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_owner && existsOnServer) _pin(),
          if (existsOnServer)
            IconButton(
              key: const Key('editor-more'),
              tooltip: 'More actions',
              onPressed: () => _openSheet(context),
              icon: const Icon(Icons.more_vert_rounded),
            )
          else if (_owner)
            _labels(),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_owner && existsOnServer) _pin(),
        if (_owner) _labels(),
        if (canEdit && existsOnServer)
          IconButton(
            key: const Key('editor-attach'),
            tooltip: 'Attach files',
            onPressed: onAttach,
            icon: const Icon(Icons.attach_file_rounded),
          ),
        if (existsOnServer)
          PopupMenuButton<EditorAction>(
            key: const Key('editor-more'),
            tooltip: 'More actions',
            position: PopupMenuPosition.under,
            onSelected: onAction,
            itemBuilder: (_) => [
              if (_owner)
                const PopupMenuItem(
                  value: EditorAction.share,
                  child: MenuRow(
                    icon: Icons.person_add_alt_outlined,
                    label: 'Share',
                  ),
                ),
              if (_owner)
                PopupMenuItem(
                  value: EditorAction.protection,
                  child: MenuRow(
                    icon: note.isProtected
                        ? Icons.lock_rounded
                        : Icons.lock_outline_rounded,
                    label: 'Password protection',
                  ),
                ),
              const PopupMenuItem(
                value: EditorAction.summary,
                child: MenuRow(
                  icon: Icons.auto_awesome_outlined,
                  label: 'AI summary',
                ),
              ),
              if (_owner) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: EditorAction.delete,
                  child: MenuRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    destructive: true,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

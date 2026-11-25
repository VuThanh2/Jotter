import 'package:flutter/material.dart';
import 'package:jotter/models/jotter_note.dart';

enum EditorAction { share, protection, summary, delete }

/// Note actions in the editor app bar, shown according to the user's access.
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

  @override
  Widget build(BuildContext context) {
    final owner = note.isOwned;
    final error = Theme.of(context).colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (owner && existsOnServer)
          IconButton(
            key: const Key('editor-pin'),
            tooltip: note.isPinned ? 'Unpin' : 'Pin to top',
            isSelected: note.isPinned,
            onPressed: onPin,
            icon: const Icon(Icons.push_pin_outlined),
            selectedIcon: const Icon(Icons.push_pin),
          ),
        if (owner)
          IconButton(
            key: const Key('editor-labels'),
            tooltip: 'Labels',
            onPressed: onLabels,
            icon: const Icon(Icons.label_outline_rounded),
          ),
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
            onSelected: onAction,
            itemBuilder: (_) => [
              if (owner)
                const PopupMenuItem(
                  value: EditorAction.share,
                  child: ListTile(
                    leading: Icon(Icons.person_add_alt_outlined),
                    title: Text('Share'),
                  ),
                ),
              if (owner)
                const PopupMenuItem(
                  value: EditorAction.protection,
                  child: ListTile(
                    leading: Icon(Icons.lock_outline_rounded),
                    title: Text('Password protection'),
                  ),
                ),
              const PopupMenuItem(
                value: EditorAction.summary,
                child: ListTile(
                  leading: Icon(Icons.auto_awesome_outlined),
                  title: Text('AI summary'),
                ),
              ),
              if (owner)
                PopupMenuItem(
                  value: EditorAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: error),
                    title: Text('Delete', style: TextStyle(color: error)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

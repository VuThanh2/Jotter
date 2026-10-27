import 'package:flutter/material.dart';

import '../models/jotter_label.dart';
import '../models/jotter_note.dart';
import '../theme.dart';

enum NoteAction { pin, labels, files, sharing, protection, summary, delete }

class NoteCard extends StatefulWidget {
  NoteCard({
    super.key,
    required this.note,
    required this.labels,
    required this.onOpen,
    required this.onAction,
    this.listMode = false,
    this.defaultColor,
    this.sharedBy,
  });
  final JotterNote note;
  final List<JotterLabel> labels;
  final VoidCallback onOpen;
  final ValueChanged<NoteAction> onAction;
  final bool listMode;
  final Color? defaultColor;
  final String? sharedBy;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _hovered = false;

  Color get _color {
    if (widget.note.isProtected)
      return context.jotterColors.tint(JotterColors.lavender);
    if (widget.defaultColor != null)
      return context.jotterColors.tint(widget.defaultColor!);
    final label = widget.labels
        .where((label) => widget.note.labelIds.contains(label.id))
        .firstOrNull;
    if (label == null)
      return Theme.of(context).colorScheme.surfaceContainerLowest;
    final name = label.name.toLowerCase();
    if (name.contains('work'))
      return context.jotterColors.tint(JotterColors.butter);
    if (name.contains('personal'))
      return context.jotterColors.tint(JotterColors.sage);
    if (name.contains('idea'))
      return context.jotterColors.tint(JotterColors.peach);
    return context.jotterColors.tint(
      [
        JotterColors.butter,
        JotterColors.sage,
        JotterColors.peach,
        JotterColors.lavender,
      ][label.name.codeUnits.fold(0, (sum, value) => sum + value) % 4],
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final tags = widget.labels
        .where((label) => note.labelIds.contains(label.id))
        .toList();
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _color,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: _hovered
                ? context.jotterColors.muted.withValues(alpha: .5)
                : context.jotterColors.ink.withValues(alpha: .08),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .04),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: widget.onOpen,
            child: Padding(
              padding: EdgeInsets.all(widget.listMode ? 19 : 23),
              child: widget.listMode
                  ? _listContent(note)
                  : _gridContent(note, tags),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridContent(JotterNote note, List<JotterLabel> tags) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            note.isProtected
                ? Icons.lock_outline_rounded
                : note.isShared
                ? Icons.people_outline_rounded
                : Icons.notes_rounded,
            size: 18,
            color: context.jotterColors.muted,
          ),
          Spacer(),
          if (note.isPinned)
            Padding(
              padding: EdgeInsets.only(right: 9),
              child: Icon(
                Icons.push_pin_rounded,
                size: 15,
                color: JotterColors.accent,
              ),
            ),
          _menu(note),
        ],
      ),
      SizedBox(height: 16),
      Text(
        note.title.isEmpty ? 'Untitled note' : note.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: -.35,
        ),
      ),
      SizedBox(height: 11),
      Expanded(
        child: Text(
          note.isProtected
              ? 'A little privacy for your thoughts.\nOpen to unlock this note.'
              : (note.contentLoaded ? note.content : note.preview),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.65,
            color: context.jotterColors.muted,
          ),
        ),
      ),
      SizedBox(height: 14),
      if (tags.isNotEmpty)
        Padding(
          padding: EdgeInsets.only(bottom: 13),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: tags.take(2).map((label) => _tag(label.name)).toList(),
          ),
        ),
      Row(
        children: [
          Text(
            relativeDate(note.updatedAt),
            style: TextStyle(fontSize: 11, color: context.jotterColors.muted),
          ),
          Spacer(),
          if (!note.isOwned)
            Icon(
              Icons.people_outline_rounded,
              size: 15,
              color: context.jotterColors.muted,
            ),
          if (note.isProtected)
            Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: context.jotterColors.muted,
            ),
        ],
      ),
    ],
  );

  Widget _listContent(JotterNote note) => Row(
    children: [
      Icon(
        note.isProtected ? Icons.lock_outline_rounded : Icons.notes_rounded,
        color: context.jotterColors.muted,
        size: 22,
      ),
      SizedBox(width: 17),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              note.title.isEmpty ? 'Untitled note' : note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 5),
            Text(
              note.isProtected
                  ? 'Protected note'
                  : (note.contentLoaded ? note.content : note.preview)
                        .replaceAll('\n', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.jotterColors.muted),
            ),
          ],
        ),
      ),
      SizedBox(width: 12),
      if (note.isPinned)
        Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(
            Icons.push_pin_rounded,
            size: 15,
            color: JotterColors.accent,
          ),
        ),
      if (MediaQuery.sizeOf(context).width > 600)
        Padding(
          padding: EdgeInsets.only(right: 12),
          child: Text(
            relativeDate(note.updatedAt),
            style: TextStyle(fontSize: 11, color: context.jotterColors.muted),
          ),
        ),
      _menu(note),
    ],
  );

  Widget _menu(JotterNote note) {
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<NoteAction>(
        tooltip: 'Note actions',
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_horiz_rounded,
          size: 20,
          color: context.jotterColors.muted,
        ),
        onSelected: widget.onAction,
        itemBuilder: (_) => [
          PopupMenuItem(value: NoteAction.files, child: Text('Files')),
          PopupMenuItem(value: NoteAction.summary, child: Text('AI summary')),
          if (note.isOwned) ...[
            PopupMenuItem(
              value: NoteAction.sharing,
              child: Text('Share & permissions'),
            ),
            PopupMenuItem(
              value: NoteAction.protection,
              child: Text('Note protection'),
            ),
            PopupMenuItem(
              value: NoteAction.pin,
              child: Text(note.isPinned ? 'Unpin note' : 'Pin note'),
            ),
            PopupMenuItem(value: NoteAction.labels, child: Text('Edit labels')),
            PopupMenuItem(
              value: NoteAction.delete,
              child: Text(
                'Delete note',
                style: TextStyle(color: JotterColors.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String name) => Container(
    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      name,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: context.jotterColors.muted,
      ),
    ),
  );
}

String relativeDate(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(local.year, local.month, local.day)).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}${local.year == now.year ? '' : ', ${local.year}'}';
}

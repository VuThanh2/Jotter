import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/jotter_label.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/note_status_indicators.dart';

/// One card for both grid and list layouts. [menu] and [footer] let each
/// screen add its own actions and metadata.
class NoteCard extends StatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onOpen,
    this.labels = const [],
    this.listMode = false,
    this.color,
    this.menu,
    this.footer,
  });

  final JotterNote note;
  final VoidCallback onOpen;
  final List<JotterLabel> labels;
  final bool listMode;
  final Color? color;
  final Widget? menu;
  final Widget? footer;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _hovered = false;

  JotterNote get _note => widget.note;

  String get _title => _note.title.isEmpty ? 'Untitled note' : _note.title;

  String get _body => _note.isProtected
      ? 'Locked · open to unlock'
      : (_note.contentLoaded ? _note.content : _note.preview);

  List<JotterLabel> get _tags => widget.labels
      .where((label) => _note.labelIds.contains(label.id))
      .toList();

  Color _background(BuildContext context) {
    final palette = context.jotterColors;
    if (_note.isProtected) return palette.tint(JotterColors.lavender);
    if (widget.color != null) return palette.tint(widget.color!);
    return palette.dark
        ? palette.sidebar
        : Theme.of(context).colorScheme.surfaceContainerLowest;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    // The title text inside already names the card; repeating it as a label
    // made screen readers announce it twice.
    return Semantics(
      container: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: _background(context),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: _hovered
                  ? palette.muted.withValues(alpha: .5)
                  : palette.ink.withValues(alpha: .08),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: widget.onOpen,
              child: Padding(
                padding: EdgeInsets.all(widget.listMode ? 16 : 20),
                child: widget.listMode ? _list(context) : _grid(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grid(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          NoteStatusIndicators(note: _note),
          const Spacer(),
          ?widget.menu,
        ],
      ),
      const SizedBox(height: 10),
      Text(
        _title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 17,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        // Show only whole lines so the last one is never cut in half.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final lineHeight = MediaQuery.textScalerOf(context).scale(13) * 1.6;
            final lines = (constraints.maxHeight / lineHeight).floor().clamp(
              0,
              6,
            );
            if (lines == 0) return const SizedBox.shrink();
            return Text(
              _body,
              maxLines: lines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: context.jotterColors.muted,
              ),
            );
          },
        ),
      ),
      if (_tags.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [for (final label in _tags.take(3)) _Tag(label.name)],
        ),
      ],
      const SizedBox(height: 10),
      widget.footer ?? _UpdatedText(_note.updatedAt),
    ],
  );

  Widget _list(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _body.replaceAll('\n', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.jotterColors.muted),
            ),
            if (_tags.isNotEmpty || widget.footer != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final label in _tags.take(3)) _Tag(label.name),
                  ?widget.footer,
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(width: 12),
      NoteStatusIndicators(note: _note),
      if (widget.footer == null && !context.isCompact) ...[
        const SizedBox(width: 10),
        _UpdatedText(_note.updatedAt),
      ],
      ?widget.menu,
    ],
  );
}

class _UpdatedText extends StatelessWidget {
  const _UpdatedText(this.date);

  final DateTime date;

  @override
  Widget build(BuildContext context) => Text(
    relativeDate(date),
    style: TextStyle(fontSize: 11, color: context.jotterColors.muted),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final year = local.year == now.year ? '' : ', ${local.year}';
  return '${months[local.month - 1]} ${local.day}$year';
}

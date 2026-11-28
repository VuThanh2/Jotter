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
    this.onLongPress,
  });

  final JotterNote note;
  final VoidCallback onOpen;
  final List<JotterLabel> labels;
  final bool listMode;
  final Color? color;
  final Widget? menu;
  final Widget? footer;

  /// Touch screens open the note's actions with a long press.
  final VoidCallback? onLongPress;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

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
    final radius = BorderRadius.circular(16);
    // No label here: the title text inside already names the card.
    return Semantics(
      container: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: _pressed ? .98 : 1,
          duration: JotterMotion.fast,
          curve: JotterMotion.curve,
          child: AnimatedContainer(
            duration: JotterMotion.medium,
            curve: JotterMotion.curve,
            // Lifts a little under the pointer so the grid feels touchable.
            transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
            decoration: BoxDecoration(
              color: _background(context),
              borderRadius: radius,
              border: Border.all(
                color: _hovered
                    ? palette.ink.withValues(alpha: .18)
                    : palette.ink.withValues(alpha: .07),
              ),
              boxShadow: [
                // Same ring as buttons, drawn outside so focus moves nothing.
                if (_focused) BoxShadow(color: palette.ink, spreadRadius: 2),
                if (_hovered) ...palette.softShadow,
              ].nullIfEmpty,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: radius,
                onTap: widget.onOpen,
                onLongPress: widget.onLongPress,
                onHighlightChanged: (pressed) =>
                    setState(() => _pressed = pressed),
                onFocusChange: (focused) => setState(() => _focused = focused),
                child: Padding(
                  padding: widget.listMode
                      ? const EdgeInsets.fromLTRB(16, 14, 8, 14)
                      : const EdgeInsets.fromLTRB(18, 14, 8, 16),
                  child: widget.listMode ? _list(context) : _grid(context),
                ),
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
      SizedBox(
        height: 32,
        child: Row(
          children: [
            NoteStatusIndicators(note: _note),
            const Spacer(),
            ?widget.menu,
          ],
        ),
      ),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
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
      ),
      const SizedBox(height: 8),
      Expanded(
        // Show only whole lines so the last one is never cut in half.
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final lineHeight =
                  MediaQuery.textScalerOf(context).scale(13.5) * 1.6;
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
                  fontSize: 13.5,
                  height: 1.6,
                  fontStyle: _note.isProtected ? FontStyle.italic : null,
                  color: context.jotterColors.muted,
                ),
              );
            },
          ),
        ),
      ),
      if (_tags.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [for (final label in _tags.take(3)) _Tag(label.name)],
        ),
      ],
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: widget.footer ?? _UpdatedText(_note.updatedAt),
      ),
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
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _body.replaceAll('\n', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                color: context.jotterColors.muted,
              ),
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
      if (widget.menu == null) const SizedBox(width: 8),
    ],
  );
}

extension on List<BoxShadow> {
  List<BoxShadow>? get nullIfEmpty => isEmpty ? null : this;
}

class _UpdatedText extends StatelessWidget {
  const _UpdatedText(this.date);

  final DateTime date;

  @override
  Widget build(BuildContext context) => Text(
    relativeDate(date),
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: context.jotterColors.muted,
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: palette.ink.withValues(alpha: palette.dark ? .1 : .055),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: .7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }
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

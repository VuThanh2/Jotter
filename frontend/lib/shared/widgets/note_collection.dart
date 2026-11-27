import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/shared/widgets/state_views.dart';

/// Lays notes out as a responsive grid or a list. Cards on screen when the
/// collection first appears slide in one after another; later ones simply
/// appear, so scrolling never waits on an animation.
class NoteCollectionSliver extends StatefulWidget {
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
  State<NoteCollectionSliver> createState() => _NoteCollectionSliverState();
}

class _NoteCollectionSliverState extends State<NoteCollectionSliver> {
  DateTime _revealUntil = DateTime.now().add(const Duration(milliseconds: 500));

  Widget _item(BuildContext context, int index) {
    final note = widget.notes[index];
    final card = widget.itemBuilder(context, note);
    if (!DateTime.now().isBefore(_revealUntil)) return card;
    return _Reveal(key: ValueKey(note.id), index: index, child: card);
  }

  @override
  void didUpdateWidget(covariant NoteCollectionSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching between grid and list deserves the same gentle entrance.
    if (oldWidget.listMode != widget.listMode) {
      _revealUntil = DateTime.now().add(const Duration(milliseconds: 500));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listMode) {
      return SliverList.separated(
        itemCount: widget.notes.length,
        itemBuilder: _item,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = noteGridColumns(constraints.crossAxisExtent);
        final compact = constraints.crossAxisExtent < 600;
        return SliverGrid.builder(
          itemCount: widget.notes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: columns == 1 ? 204 : 236,
            crossAxisSpacing: compact ? 10 : 14,
            mainAxisSpacing: compact ? 10 : 14,
          ),
          itemBuilder: _item,
        );
      },
    );
  }
}

class _Reveal extends StatefulWidget {
  const _Reveal({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  static const _step = 40;
  static const _length = 320;

  late final int _delay = widget.index.clamp(0, 10) * _step;
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _delay + _length),
  )..forward();
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(_delay / (_delay + _length), 1, curve: JotterMotion.curve),
  );

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, .06),
        end: Offset.zero,
      ).animate(_curve),
      child: widget.child,
    ),
  );
}

class NoteSectionHeading extends StatelessWidget {
  const NoteSectionHeading(
    this.title, {
    super.key,
    required this.icon,
    this.count,
  });

  final String title;
  final IconData icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final muted = context.jotterColors.muted;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: muted),
          const SizedBox(width: 7),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: muted.withValues(alpha: .7),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(child: Divider(color: context.jotterColors.line)),
        ],
      ),
    );
  }
}

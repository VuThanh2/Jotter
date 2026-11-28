import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: label,
      child: const Padding(
        padding: EdgeInsets.all(48),
        child: SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            strokeCap: StrokeCap.round,
          ),
        ),
      ),
    ),
  );
}

/// Fades and lifts its child in once, the first time it is built.
class EntranceTransition extends StatelessWidget {
  const EntranceTransition({
    super.key,
    required this.child,
    this.duration = JotterMotion.slow,
    this.offset = 10,
    this.scale = 1,
  });

  final Widget child;
  final Duration duration;

  /// How far below its place the child starts, in logical pixels.
  final double offset;

  /// Starting scale; 1 keeps the size fixed.
  final double scale;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: duration,
    curve: JotterMotion.curve,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * offset),
        child: scale == 1
            ? child
            : Transform.scale(scale: scale + (1 - scale) * value, child: child),
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.tone = JotterTone.info,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// [JotterTone.error] gives the illustration a warmer, alerting colour.
  final JotterTone tone;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: EntranceTransition(
          scale: .97,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Illustration(icon: icon, tone: tone),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: context.jotterColors.muted,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    ),
  );
}

/// A small stack of paper notes with the state's icon on the front one.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.icon, required this.tone});

  final IconData icon;
  final JotterTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final error = tone == JotterTone.error;
    Widget sheet(Color color, double angle, Offset shift) =>
        Transform.translate(
          offset: shift,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: 74,
              height: 84,
              decoration: BoxDecoration(
                color: palette.tint(color),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.ink.withValues(alpha: .06)),
              ),
            ),
          ),
        );
    final front = palette.tint(
      error ? JotterColors.peach : JotterColors.butter,
    );
    final iconColor = error
        ? palette.accent
        : (palette.dark ? const Color(0xFFD9C38F) : const Color(0xFFAA9566));
    return ExcludeSemantics(
      child: SizedBox(
        width: 132,
        height: 104,
        child: Stack(
          alignment: Alignment.center,
          children: [
            sheet(JotterColors.sage, -.2, const Offset(-22, 4)),
            sheet(JotterColors.lavender, .18, const Offset(22, 4)),
            Container(
              width: 78,
              height: 88,
              decoration: BoxDecoration(
                color: front,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: palette.ink.withValues(alpha: .07)),
                boxShadow: palette.softShadow,
              ),
              child: Icon(icon, size: 34, color: iconColor),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyView(
    icon: Icons.cloud_off_outlined,
    tone: JotterTone.error,
    title: 'Something got in the way',
    message: message,
    action: onRetry == null
        ? null
        : OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
  );
}

/// An inline notice or error shown inside a page.
class MessageStrip extends StatelessWidget {
  const MessageStrip(
    this.text, {
    super.key,
    this.error = false,
    this.action,
    this.tone,
    this.icon,
  });

  final String text;
  final bool error;
  final Widget? action;

  /// Overrides [error] when set.
  final JotterTone? tone;
  final IconData? icon;

  JotterTone get _tone => tone ?? (error ? JotterTone.error : JotterTone.info);

  IconData get _icon =>
      icon ??
      switch (_tone) {
        JotterTone.info => Icons.info_outline_rounded,
        JotterTone.success => Icons.check_circle_outline_rounded,
        JotterTone.warning => Icons.warning_amber_rounded,
        JotterTone.error => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.jotterColors.tone(_tone);
    return Semantics(
      liveRegion: true,
      child: EntranceTransition(
        duration: JotterMotion.medium,
        offset: -6,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(12, 10, action == null ? 14 : 6, 10),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(_icon, size: 19, color: colors.icon),
              ),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: colors.foreground,
                  ),
                ),
              ),
              if (action != null)
                TextButtonTheme(
                  data: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.foreground,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  child: action!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder cards with a gentle pulse while the first notes load.
class NoteSkeletonSliver extends StatefulWidget {
  const NoteSkeletonSliver({
    super.key,
    required this.listMode,
    this.label = 'Loading',
  });

  final bool listMode;
  final String label;

  @override
  State<NoteSkeletonSliver> createState() => _NoteSkeletonSliverState();
}

class _NoteSkeletonSliverState extends State<NoteSkeletonSliver>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final bar = palette.ink.withValues(alpha: palette.dark ? .1 : .07);
    Widget line(double width, [double height = 10]) => FractionallySizedBox(
      widthFactor: width,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: bar,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
    Widget card(int index) => Container(
      padding: EdgeInsets.all(widget.listMode ? 16 : 20),
      decoration: BoxDecoration(
        color: palette.dark ? palette.sidebar : palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.ink.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          line(index.isEven ? .55 : .7, 14),
          const SizedBox(height: 14),
          line(.95),
          const SizedBox(height: 9),
          line(.8),
          if (!widget.listMode) ...[
            const SizedBox(height: 9),
            line(.88),
            const SizedBox(height: 9),
            line(.4),
          ],
        ],
      ),
    );
    final cards = SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = widget.listMode
            ? 1
            : noteGridColumns(constraints.crossAxisExtent);
        return SliverGrid.builder(
          itemCount: widget.listMode ? 5 : columns * 2,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: widget.listMode ? 96 : 200,
            crossAxisSpacing: 14,
            mainAxisSpacing: widget.listMode ? 10 : 14,
          ),
          itemBuilder: (context, index) => card(index),
        );
      },
    );
    return SliverSemantics(
      label: widget.label,
      sliver: SliverFadeTransition(
        opacity: Tween<double>(
          begin: .45,
          end: 1,
        ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        sliver: cards,
      ),
    );
  }
}

/// Columns for note grids, shared by cards and their loading placeholders.
/// Phones get two columns like other note apps; only very narrow screens
/// fall back to one.
int noteGridColumns(double width) => width >= 1100
    ? 4
    : width >= 780
    ? 3
    : width >= 320
    ? 2
    : 1;

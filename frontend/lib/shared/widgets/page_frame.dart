import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';

extension WideLayoutContext on BuildContext {
  /// Desktop-width windows, where secondary pages use two columns.
  bool get isExpanded => windowSize == WindowSize.expanded;
}

/// Scaffold for secondary pages with a back button that also works when the
/// page was opened directly from a URL.
///
/// Phones and tablets get a single column under a plain app bar. Desktop
/// widths get a header band with the title, and [aside] as a left column
/// beside the content, so the page uses the window instead of a narrow strip.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.fallbackRoute,
    required this.child,
    this.maxWidth = 560,
    this.actions = const [],
    this.scrollable = true,
    this.banner,
    this.subtitle,
    this.icon,
    this.aside,
    this.wideMaxWidth = 1040,
    this.cardOnWide = false,
  });

  final String title;
  final String fallbackRoute;
  final Widget child;
  final double maxWidth;
  final List<Widget> actions;
  final bool scrollable;

  /// Full-width strip pinned under the app bar, e.g. the unverified notice.
  final Widget? banner;

  /// Shown under the title in the desktop header band.
  final String? subtitle;
  final IconData? icon;

  /// The left column on desktop widths; not shown on narrower screens.
  final Widget? aside;
  final double wideMaxWidth;

  /// Wraps [child] in a card on desktop, for forms that would otherwise
  /// float on the page.
  final bool cardOnWide;

  @override
  Widget build(BuildContext context) {
    final wide = context.isExpanded;
    final back = BackButton(
      onPressed: () =>
          context.canPop() ? context.pop() : context.go(fallbackRoute),
    );
    if (!wide) {
      final body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: child,
          ),
        ),
      );
      return Scaffold(
        appBar: AppBar(title: Text(title), leading: back, actions: actions),
        body: Column(
          children: [
            ?banner,
            Expanded(
              child: SafeArea(
                top: false,
                child: scrollable ? SingleChildScrollView(child: body) : body,
              ),
            ),
          ],
        ),
      );
    }
    final palette = context.jotterColors;
    Widget main = child;
    if (cardOnWide) {
      main = Container(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.line),
        ),
        child: main,
      );
    }
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wideMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 28, 40, 48),
          child: aside == null
              ? main
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 300, child: aside),
                    const SizedBox(width: 36),
                    Expanded(child: main),
                  ],
                ),
        ),
      ),
    );
    final page = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderBand(
          title: title,
          subtitle: subtitle,
          icon: icon,
          maxWidth: wideMaxWidth,
        ),
        content,
      ],
    );
    return Scaffold(
      appBar: AppBar(
        leading: back,
        actions: actions,
        backgroundColor: palette.sidebar,
      ),
      body: Column(
        children: [
          ?banner,
          Expanded(
            child: SafeArea(
              top: false,
              child: scrollable ? SingleChildScrollView(child: page) : page,
            ),
          ),
        ],
      ),
    );
  }
}

/// The desktop page title on a softly ruled band, like the top of a notepad.
class _HeaderBand extends StatelessWidget {
  const _HeaderBand({
    required this.title,
    required this.maxWidth,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.sidebar, palette.paper],
        ),
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: CustomPaint(
        painter: _RuledPaper(palette.ink.withValues(alpha: .045)),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 4, 40, 28),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.line),
                        boxShadow: palette.softShadow,
                      ),
                      child: Icon(icon, color: palette.accent, size: 25),
                    ),
                    const SizedBox(width: 18),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 15,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faint horizontal rules with a margin line, fading towards the bottom.
class _RuledPaper extends CustomPainter {
  const _RuledPaper(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 24.0;
    for (var y = gap; y < size.height; y += gap) {
      final fade = 1 - (y / size.height);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = color.withValues(alpha: color.a * fade)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_RuledPaper oldDelegate) => oldDelegate.color != color;
}

/// A left-column intro for desktop pages: what the page is for, plus tips.
class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.heading,
    required this.body,
    this.points = const [],
  });

  final String heading;
  final String body;
  final List<(IconData, String)> points;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(fontSize: 14, height: 1.6, color: palette.muted),
        ),
        if (points.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (final (icon, text) in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: palette.selected,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 15, color: palette.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

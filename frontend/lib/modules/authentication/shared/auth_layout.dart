import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/jotter_mark.dart';
import 'package:jotter/shared/widgets/state_views.dart';

/// Frame shared by the public screens: login, register and password reset.
/// Phones get a full-bleed form, tablets a centred card and desktops a
/// split view with the brand beside the form.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    final wide = size == WindowSize.expanded;
    final carded = size == WindowSize.medium;
    final palette = context.jotterColors;
    Widget form = AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!wide) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: JotterMark(size: 24),
            ),
            SizedBox(height: carded ? 28 : 40),
          ],
          ?leading,
          AnimatedSwitcher(
            duration: JotterMotion.medium,
            child: Column(
              key: ValueKey(title),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
    if (carded) {
      form = Container(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.line),
          boxShadow: palette.softShadow,
        ),
        child: form,
      );
    }
    final page = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: carded ? 32 : 24,
          vertical: 32,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: carded ? 460 : 400),
          child: EntranceTransition(offset: 14, child: form),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: carded ? palette.sidebar : null,
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  const Expanded(flex: 11, child: _BrandPanel()),
                  Expanded(flex: 10, child: page),
                ],
              )
            : page,
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.sidebar, palette.tint(JotterColors.peach)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const JotterMark(size: 26),
          const Expanded(
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: _NotesArt()),
            ),
          ),
          Text(
            'A little less to remember.\nA little more room to think.',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(height: 1.25),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'Your notes stay with you on the web and on your phone, '
              'even when the connection drops.',
              style: TextStyle(fontSize: 15, height: 1.6, color: palette.muted),
            ),
          ),
          const SizedBox(height: 22),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Feature(Icons.cloud_off_outlined, 'Works offline'),
              _Feature(Icons.people_outline_rounded, 'Share & edit live'),
              _Feature(Icons.auto_awesome_outlined, 'Ask AI'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.accent),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Three paper notes fanned out, drawn from the same shapes as note cards.
class _NotesArt extends StatelessWidget {
  const _NotesArt();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 360,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ArtCard(
            color: JotterColors.sage,
            angle: -.14,
            offset: const Offset(-96, 22),
            delay: 0,
            title: .6,
            icon: Icons.checklist_rounded,
          ),
          _ArtCard(
            color: JotterColors.lavender,
            angle: .12,
            offset: const Offset(98, 30),
            delay: 1,
            title: .5,
            icon: Icons.lock_outline_rounded,
          ),
          _ArtCard(
            color: JotterColors.butter,
            angle: -.02,
            offset: const Offset(0, -6),
            delay: 2,
            title: .7,
            icon: Icons.push_pin_rounded,
            front: true,
          ),
        ],
      ),
    ),
  );
}

class _ArtCard extends StatelessWidget {
  const _ArtCard({
    required this.color,
    required this.angle,
    required this.offset,
    required this.delay,
    required this.title,
    required this.icon,
    this.front = false,
  });

  final Color color;
  final double angle;
  final Offset offset;
  final int delay;
  final double title;
  final IconData icon;
  final bool front;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final bar = palette.ink.withValues(alpha: palette.dark ? .16 : .1);
    Widget line(double factor, [double height = 7]) => FractionallySizedBox(
      widthFactor: factor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: bar,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + delay * 140),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.translate(
        offset: offset + Offset(0, (1 - value) * 30),
        child: Transform.rotate(
          angle: angle * value,
          child: Opacity(opacity: value.clamp(0, 1), child: child),
        ),
      ),
      child: Container(
        width: front ? 176 : 156,
        height: front ? 196 : 176,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.tint(color),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.ink.withValues(alpha: .07)),
          boxShadow: palette.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: front ? palette.accent : palette.muted),
            const SizedBox(height: 14),
            line(title, 11),
            const SizedBox(height: 14),
            line(.95),
            const SizedBox(height: 8),
            line(.85),
            const SizedBox(height: 8),
            line(.9),
            const SizedBox(height: 8),
            line(.45),
          ],
        ),
      ),
    );
  }
}

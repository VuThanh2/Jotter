import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';
import 'package:jotter/shared/widgets/jotter_mark.dart';

/// Frame shared by the public screens: login, register and password reset.
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
    final wide = context.windowSize == WindowSize.expanded;
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!wide) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: JotterMark(size: 24),
                  ),
                  const SizedBox(height: 36),
                ],
                ?leading,
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: context.jotterColors.muted,
                  ),
                ),
                const SizedBox(height: 28),
                child,
              ],
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  const Expanded(child: _BrandPanel()),
                  Expanded(child: form),
                ],
              )
            : form,
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) => Container(
    color: context.jotterColors.sidebar,
    padding: const EdgeInsets.all(56),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const JotterMark(size: 28),
        const Spacer(),
        Text(
          'A little less to remember.\nA little more room to think.',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(height: 1.3),
        ),
        const SizedBox(height: 16),
        Text(
          'Your notes stay with you on the web and on your phone, '
          'even when the connection drops.',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: context.jotterColors.muted,
          ),
        ),
        const Spacer(flex: 2),
      ],
    ),
  );
}

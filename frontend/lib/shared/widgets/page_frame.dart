import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Scaffold for secondary pages with a back button that also works when the
/// page was opened directly from a URL.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.fallbackRoute,
    required this.child,
    this.maxWidth = 560,
    this.actions = const [],
    this.scrollable = true,
  });

  final String title;
  final String fallbackRoute;
  final Widget child;
  final double maxWidth;
  final List<Widget> actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(
        title: Text(title),
        leading: BackButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(fallbackRoute),
        ),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        child: scrollable ? SingleChildScrollView(child: body) : body,
      ),
    );
  }
}

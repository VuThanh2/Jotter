import 'package:flutter/widgets.dart';

/// Page-wide keyboard shortcuts. Focus left on the route after clicking away
/// from a text field is pulled back into the page so they keep working.
class PageShortcuts extends StatefulWidget {
  const PageShortcuts({
    super.key,
    required this.bindings,
    required this.child,
    this.autofocus = false,
  });

  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  /// Leave false when a field on the page focuses itself, so it is not
  /// overruled.
  final bool autofocus;

  @override
  State<PageShortcuts> createState() => _PageShortcutsState();
}

class _PageShortcutsState extends State<PageShortcuts> {
  final _focus = FocusNode(debugLabel: 'page-shortcuts');
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_keepFocusInPage);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_keepFocusInPage);
    _focus.dispose();
    super.dispose();
  }

  void _keepFocusInPage() {
    if (!mounted) return;
    final leftPage =
        _hadFocus &&
        FocusManager.instance.primaryFocus == _focus.enclosingScope;
    _hadFocus = _focus.hasFocus;
    if (leftPage) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: widget.bindings,
    child: Focus(
      focusNode: _focus,
      autofocus: widget.autofocus,
      child: widget.child,
    ),
  );
}

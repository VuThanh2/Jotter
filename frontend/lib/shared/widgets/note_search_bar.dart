import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';

class NoteSearchBar extends StatelessWidget {
  const NoteSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.hint = 'Search your notes…',
    this.shortcutHint = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final String hint;

  /// Shows the Ctrl/⌘ K keycap on keyboard-first platforms.
  final bool shortcutHint;

  static bool get _touchPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final radius = BorderRadius.circular(14);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) {
        final Widget? suffix = value.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : shortcutHint && !_touchPlatform
            ? _Keycap(
                defaultTargetPlatform == TargetPlatform.macOS
                    ? '⌘ K'
                    : 'Ctrl K',
              )
            : null;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.search_rounded, size: 21, color: palette.muted),
            ),
            suffixIcon: AnimatedSwitcher(
              duration: JotterMotion.fast,
              child: KeyedSubtree(
                key: ValueKey(suffix.runtimeType),
                child: suffix ?? const SizedBox.shrink(),
              ),
            ),
            fillColor: palette.dark ? palette.sidebar : palette.surface,
            border: border(palette.line),
            enabledBorder: border(palette.line),
            focusedBorder: border(palette.accent, 1.6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        );
      },
    );
  }
}

class _Keycap extends StatelessWidget {
  const _Keycap(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return ExcludeSemantics(
      child: Center(
        widthFactor: 1,
        child: Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: palette.paper,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: palette.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
        ),
      ),
    );
  }
}

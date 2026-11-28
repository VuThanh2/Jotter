import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/shared/widgets/adaptive_scaffold.dart';

/// A dialog that scales up gently from the centre instead of only fading.
Future<T?> showJotterDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final theme = Theme.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor:
        theme.dialogTheme.barrierColor ?? Colors.black.withValues(alpha: .32),
    transitionDuration: JotterMotion.medium,
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: .95, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Opens [builder]'s [ModalPanel] the way each platform expects it: a sheet
/// that rises from the bottom on phones, a centred dialog on wider screens.
Future<T?> showAdaptivePanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  if (context.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) =>
          _PanelPresentation(sheet: true, child: Builder(builder: builder)),
    );
  }
  return showJotterDialog<T>(context, builder: builder);
}

class _PanelPresentation extends InheritedWidget {
  const _PanelPresentation({required this.sheet, required super.child});

  final bool sheet;

  static bool isSheet(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PanelPresentation>()?.sheet ??
      false;

  @override
  bool updateShouldNotify(_PanelPresentation oldWidget) =>
      sheet != oldWidget.sheet;
}

/// The frame shared by note panels: a title with a close button, a scrolling
/// body and an optional footer. Shown as a sheet or a dialog by
/// [showAdaptivePanel].
class ModalPanel extends StatelessWidget {
  const ModalPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.busy = false,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final bool busy;

  /// Shown in a soft badge before the title.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final sheet = _PanelPresentation.isSheet(context);
    final palette = context.jotterColors;
    final text = Theme.of(context).textTheme;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(22, sheet ? 6 : 18, 10, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: palette.accent),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleLarge),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.close_rounded, color: palette.muted),
          ),
        ],
      ),
    );
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sheet) const _DragHandle(),
        header,
        SizedBox(
          height: 2,
          child: AnimatedSwitcher(
            duration: JotterMotion.fast,
            child: busy
                ? const LinearProgressIndicator(key: ValueKey('busy'))
                : Divider(key: const ValueKey('idle'), color: palette.line),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(22, 18, 22, footer == null ? 24 : 12),
            child: child,
          ),
        ),
        if (footer != null)
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.line)),
            ),
            child: footer,
          ),
      ],
    );
    if (sheet) {
      // Text fields in the sheet stay above the soft keyboard.
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(top: false, child: body),
      );
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: body,
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: context.jotterColors.muted.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// A titled bottom sheet of actions for phones, e.g. a note's menu.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<ActionSheetItem<T>> items,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  builder: (context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  if (subtitle != null) Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
            for (final item in items)
              _ActionSheetTile(
                item: item,
                onTap: () => Navigator.pop(context, item.value),
              ),
          ],
        ),
      ),
    );
  },
);

class ActionSheetItem<T> {
  const ActionSheetItem({
    required this.value,
    required this.icon,
    required this.label,
    this.destructive = false,
    this.selected = false,
  });

  final T value;
  final IconData icon;
  final String label;
  final bool destructive;
  final bool selected;
}

class _ActionSheetTile<T> extends StatelessWidget {
  const _ActionSheetTile({required this.item, required this.onTap});

  final ActionSheetItem<T> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final color = item.destructive
        ? Theme.of(context).colorScheme.error
        : palette.ink;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: item.destructive
              ? Theme.of(context).colorScheme.error.withValues(alpha: .1)
              : item.selected
              ? palette.accentSoft
              : palette.selected,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          item.icon,
          size: 19,
          color: item.selected && !item.destructive ? palette.accent : color,
        ),
      ),
      title: Text(item.label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

/// A compact icon-and-label row for popup menus on wide screens.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : context.jotterColors.ink;
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: destructive ? color : context.jotterColors.muted,
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: color)),
      ],
    );
  }
}

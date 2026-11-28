import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';

/// A titled card of rows separated by hairlines, as in system settings.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title!.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: palette.muted,
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Material(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, child) in children.indexed) ...[
                    if (index > 0)
                      Divider(indent: 64, height: 1, color: palette.line),
                    child,
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A settings row with a tinted icon badge.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tint,
    this.onTap,
    this.highlight = false,
    this.destructive = false,
    this.showChevron = true,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? tint;
  final VoidCallback? onTap;
  final bool highlight;
  final bool destructive;
  final bool showChevron;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.jotterColors;
    final error = Theme.of(context).colorScheme.error;
    final iconColor = destructive
        ? error
        : highlight
        ? palette.accent
        : palette.ink.withValues(alpha: .78);
    final badge = destructive
        ? error.withValues(alpha: .1)
        : tint == null
        ? palette.selected
        : palette.tint(tint!);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: badge,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
          color: destructive ? error : null,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          (showChevron
              ? Icon(Icons.chevron_right_rounded, color: palette.muted)
              : null),
    );
  }
}

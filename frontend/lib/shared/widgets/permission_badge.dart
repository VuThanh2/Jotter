import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';

class PermissionBadge extends StatelessWidget {
  const PermissionBadge({super.key, required this.canEdit});

  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final label = canEdit ? 'Can edit' : 'View only';
    final colors = context.jotterColors.tone(
      canEdit ? JotterTone.success : JotterTone.info,
    );
    return Semantics(
      label: 'Permission: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              canEdit ? Icons.edit_outlined : Icons.visibility_outlined,
              size: 12,
              color: colors.icon,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

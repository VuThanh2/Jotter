import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';

class PermissionBadge extends StatelessWidget {
  const PermissionBadge({super.key, required this.canEdit});

  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final label = canEdit ? 'Can edit' : 'View only';
    return Semantics(
      label: 'Permission: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              canEdit ? Icons.edit_outlined : Icons.visibility_outlined,
              size: 12,
              color: context.jotterColors.muted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: context.jotterColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

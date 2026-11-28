import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/shared/models/note_permission.dart';
import 'package:jotter/shared/widgets/user_avatar.dart';

/// One person in the share dialog: who they are, their access and, for
/// existing shares, a way to remove it.
class RecipientRow extends StatelessWidget {
  const RecipientRow({
    super.key,
    required this.email,
    required this.permission,
    required this.onPermissionChanged,
    this.name = '',
    this.pickerKey,
    this.onRemove,
  });

  final String email;
  final String name;
  final NotePermission permission;
  final ValueChanged<NotePermission>? onPermissionChanged;
  final Key? pickerKey;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        UserAvatar(name: name.isEmpty ? email : name, radius: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? email : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (name.isNotEmpty)
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.jotterColors.muted,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 132,
          child: Semantics(
            label: 'Access for $email',
            // Controlled by [permission], so a failed change snaps back.
            child: InputDecorator(
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<NotePermission>(
                  key: pickerKey,
                  value: permission,
                  isDense: true,
                  isExpanded: true,
                  style: TextStyle(
                    fontFamily: kJotterFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.jotterColors.ink,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    for (final value in NotePermission.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: onPermissionChanged == null
                      ? null
                      : (value) => onPermissionChanged!(value!),
                ),
              ),
            ),
          ),
        ),
        if (onRemove != null)
          IconButton(
            tooltip: 'Remove access for ${name.isEmpty ? email : name}',
            onPressed: onRemove,
            icon: const Icon(Icons.person_remove_outlined, size: 20),
          ),
      ],
    ),
  );
}

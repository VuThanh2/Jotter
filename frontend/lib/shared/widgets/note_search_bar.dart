import 'package:flutter/material.dart';
import 'package:jotter/app/theme/app_theme.dart';

class NoteSearchBar extends StatelessWidget {
  const NoteSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.hint = 'Search your notes…',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final String hint;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) => TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: context.jotterColors.muted,
        ),
        suffixIcon: value.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
      ),
    ),
  );
}

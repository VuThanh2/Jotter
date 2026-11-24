import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jotter/shared/widgets/state_views.dart';

class UnavailableNoteView extends StatelessWidget {
  const UnavailableNoteView({
    super.key,
    required this.reason,
    required this.onBack,
    this.draft,
  });

  final String reason;
  final VoidCallback onBack;

  /// Unsaved text that would otherwise be lost; offered for copying.
  final String? draft;

  @override
  Widget build(BuildContext context) => EmptyView(
    icon: Icons.do_not_disturb_on_outlined,
    title: 'This note is not available',
    message: reason,
    action: Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (draft != null && draft!.trim().isNotEmpty)
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: draft!));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Your text was copied.')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy my text'),
          ),
        FilledButton(onPressed: onBack, child: const Text('Back to notes')),
      ],
    ),
  );
}

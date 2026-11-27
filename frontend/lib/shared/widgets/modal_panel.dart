import 'package:flutter/material.dart';

/// The frame shared by note dialogs: a title with a close button, a scrolling
/// body and an optional footer, sized for phones and desktops alike.
class ModalPanel extends StatelessWidget {
  const ModalPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.busy = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final text = Theme.of(context).textTheme;
    return Dialog(
      insetPadding: EdgeInsets.all(narrow ? 12 : 28),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 8, 10),
              child: Row(
                children: [
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
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 2,
              child: busy ? const LinearProgressIndicator() : null,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  16,
                  22,
                  footer == null ? 22 : 8,
                ),
                child: child,
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

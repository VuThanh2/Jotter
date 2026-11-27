import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_inbox_cubit.dart';
import 'package:jotter/modules/sharing/shared_with_me/share_inbox_state.dart';

/// Shows a notice for newly shared notes on whatever screen is open.
class ShareAnnouncer extends StatelessWidget {
  const ShareAnnouncer({
    super.key,
    required this.onOpenNote,
    required this.child,
  });

  final ValueChanged<String> onOpenNote;
  final Widget child;

  void _announce(BuildContext context, ShareInboxState state) {
    final latest = state.latest!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(latest.message),
          duration: const Duration(seconds: 8),
          // A snackbar with an action otherwise stays until dismissed.
          persist: false,
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => onOpenNote(latest.noteId),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<ShareInboxCubit, ShareInboxState>(
        listenWhen: (previous, current) =>
            current.latest != null && previous.latest != current.latest,
        listener: _announce,
        child: child,
      );
}

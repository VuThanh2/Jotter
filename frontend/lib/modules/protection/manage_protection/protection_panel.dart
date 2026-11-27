import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/modules/protection/manage_protection/change_note_password_dialog.dart';
import 'package:jotter/modules/protection/manage_protection/disable_protection_dialog.dart';
import 'package:jotter/modules/protection/manage_protection/enable_protection_dialog.dart';
import 'package:jotter/modules/protection/manage_protection/manage_protection_cubit.dart';
import 'package:jotter/modules/protection/manage_protection/manage_protection_state.dart';
import 'package:jotter/modules/protection/manage_protection/protection_api.dart';
import 'package:jotter/shared/widgets/modal_panel.dart';
import 'package:jotter/shared/widgets/state_views.dart';

/// Resolves to true when the note's protection changed, so the editor reloads.
Future<bool> showProtectionPanel(BuildContext context, JotterNote note) async {
  final cubit = ManageProtectionCubit(
    ProtectionApi(context.read<ApiNoteRepository>()),
    noteId: note.id,
  );
  try {
    if (!note.isProtected) {
      return await showEnableProtectionDialog(context, cubit);
    }
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ProtectionPanel(title: note.title),
      ),
    );
    return changed ?? false;
  } finally {
    await cubit.close();
  }
}

class _ProtectionPanel extends StatelessWidget {
  const _ProtectionPanel({required this.title});

  final String title;

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ManageProtectionCubit, ManageProtectionState>(
    builder: (context, state) {
      final cubit = context.read<ManageProtectionCubit>();
      void finish() => Navigator.pop(context, true);
      return ModalPanel(
        title: 'Password protection',
        subtitle: title.isEmpty ? 'Untitled note' : title,
        busy: state.busy,
        footer: Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: state.busy
                  ? null
                  : () async {
                      if (await cubit.lock()) {
                        finish();
                      }
                    },
              child: const Text('Lock now'),
            ),
            OutlinedButton(
              onPressed: state.busy
                  ? null
                  : () async {
                      if (await showChangeNotePasswordDialog(context, cubit)) {
                        finish();
                      }
                    },
              child: const Text('Change password'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: state.busy
                  ? null
                  : () async {
                      if (await showDisableProtectionDialog(context, cubit)) {
                        finish();
                      }
                    },
              child: const Text('Remove password'),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This note has a password. It stays open on this device '
              'until you lock it again.',
            ),
            // Password dialogs above this panel show their own errors.
            if (state.error != null &&
                (ModalRoute.of(context)?.isCurrent ?? true)) ...[
              const SizedBox(height: 14),
              MessageStrip(state.error!, error: true),
            ],
          ],
        ),
      );
    },
  );
}

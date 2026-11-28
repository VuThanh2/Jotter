import 'package:flutter/widgets.dart';
import 'package:jotter/modules/protection/manage_protection/manage_protection_cubit.dart';
import 'package:jotter/modules/protection/manage_protection/note_password_dialog.dart';

Future<bool> showEnableProtectionDialog(
  BuildContext context,
  ManageProtectionCubit cubit,
) => showNotePasswordDialog(
  context,
  cubit,
  title: 'Add a password',
  message:
      'Anyone opening this note will need this password, including people '
      'you share it with. It is separate from your account password.',
  inputs: const [NotePasswordInput.newPassword, NotePasswordInput.confirmation],
  submitLabel: 'Add password',
  onSubmit: (values) => cubit.enable(
    values[NotePasswordInput.newPassword]!,
    values[NotePasswordInput.confirmation]!,
  ),
);

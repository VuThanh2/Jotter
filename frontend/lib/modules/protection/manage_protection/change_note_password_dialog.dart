import 'package:flutter/widgets.dart';
import 'package:jotter/modules/protection/manage_protection/manage_protection_cubit.dart';
import 'package:jotter/modules/protection/manage_protection/note_password_dialog.dart';

Future<bool> showChangeNotePasswordDialog(
  BuildContext context,
  ManageProtectionCubit cubit,
) => showNotePasswordDialog(
  context,
  cubit,
  title: 'Change note password',
  message: 'Every device will need the new password to open this note.',
  inputs: const [
    NotePasswordInput.current,
    NotePasswordInput.newPassword,
    NotePasswordInput.confirmation,
  ],
  submitLabel: 'Change password',
  onSubmit: (values) => cubit.changePassword(
    values[NotePasswordInput.current]!,
    values[NotePasswordInput.newPassword]!,
    values[NotePasswordInput.confirmation]!,
  ),
);

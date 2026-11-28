import 'package:flutter/widgets.dart';
import 'package:jotter/modules/protection/manage_protection/manage_protection_cubit.dart';
import 'package:jotter/modules/protection/manage_protection/note_password_dialog.dart';

Future<bool> showDisableProtectionDialog(
  BuildContext context,
  ManageProtectionCubit cubit,
) => showNotePasswordDialog(
  context,
  cubit,
  title: 'Remove the password?',
  message:
      'Anyone with access will be able to open this note without a '
      'password.',
  inputs: const [NotePasswordInput.current],
  submitLabel: 'Remove password',
  destructive: true,
  onSubmit: (values) => cubit.disable(values[NotePasswordInput.current]!),
);

import 'package:flutter/widgets.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/shared/widgets/confirm_dialog.dart';

Future<bool> confirmDeleteNote(BuildContext context, JotterNote note) =>
    showConfirmDialog(
      context,
      title: 'Delete this note?',
      message:
          '“${note.title.isEmpty ? 'Untitled note' : note.title}” and its '
          'attachments will be deleted for everyone it is shared with. '
          'This cannot be undone.',
      confirmLabel: 'Delete note',
      cancelLabel: 'Keep note',
    );

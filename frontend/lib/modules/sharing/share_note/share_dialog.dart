import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jotter/app/theme/app_theme.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/models/note_features.dart';
import 'package:jotter/modules/sharing/share_note/recipient_row.dart';
import 'package:jotter/modules/sharing/share_note/share_note_api.dart';
import 'package:jotter/modules/sharing/share_note/share_note_cubit.dart';
import 'package:jotter/modules/sharing/share_note/share_note_state.dart';
import 'package:jotter/shared/models/note_permission.dart';
import 'package:jotter/shared/widgets/confirm_dialog.dart';
import 'package:jotter/shared/widgets/modal_panel.dart';
import 'package:jotter/shared/widgets/state_views.dart';

Future<void> showShareDialog(BuildContext context, JotterNote note) {
  final api = ShareNoteApi(context.read<ApiNoteRepository>());
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => ShareNoteCubit(api, noteId: note.id)..load(),
      child: _ShareDialog(noteTitle: note.title),
    ),
  );
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.noteTitle});

  final String noteTitle;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  final _emails = TextEditingController();

  ShareNoteCubit get _cubit => context.read<ShareNoteCubit>();

  @override
  void dispose() {
    _emails.dispose();
    super.dispose();
  }

  /// Unique addresses in typing order, ignoring case.
  List<String> get _typedEmails {
    final unique = <String, String>{};
    for (final part in _emails.text.split(RegExp(r'[,;\s]+'))) {
      if (part.isNotEmpty) unique.putIfAbsent(part.toLowerCase(), () => part);
    }
    return unique.values.toList();
  }

  Future<void> _invite() async {
    final rejected = await _cubit.invite(_typedEmails);
    if (rejected != null && mounted) {
      setState(() => _emails.text = rejected.join(', '));
    }
  }

  Future<void> _revoke(NoteShare share) async {
    final name = share.displayName.isEmpty ? share.email : share.displayName;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove $name?',
      message: '$name will no longer be able to open this note.',
      confirmLabel: 'Remove access',
    );
    if (confirmed) await _cubit.revoke(share);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ShareNoteCubit, ShareNoteState>(
    builder: (context, state) {
      final muted = context.jotterColors.muted;
      final invitees = _typedEmails.where(_emailPattern.hasMatch);
      return ModalPanel(
        title: 'Share',
        subtitle: widget.noteTitle.isEmpty ? 'Untitled note' : widget.noteTitle,
        busy: state.busy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invite people who have a Jotter account. Separate '
              'emails with commas.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('share-emails'),
              controller: _emails,
              autofocus: true,
              // Read-only rather than disabled keeps focus for the next invite.
              readOnly: state.busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _invite(),
              decoration: const InputDecoration(
                labelText: 'Email addresses',
                hintText: 'name@example.com',
              ),
            ),
            const SizedBox(height: 8),
            for (final email in invitees)
              RecipientRow(
                email: email,
                permission: state.permissionFor(email),
                pickerKey: ValueKey('invite-permission:${email.toLowerCase()}'),
                onPermissionChanged: state.busy
                    ? null
                    : (value) => _cubit.setInvitePermission(email, value),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                key: const Key('share-send'),
                onPressed: state.busy || _emails.text.trim().isEmpty
                    ? null
                    : _invite,
                child: const Text('Send invitation'),
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 14),
              MessageStrip(state.error!, error: true),
            ],
            if (state.notice != null) ...[
              const SizedBox(height: 14),
              MessageStrip(state.notice!),
            ],
            const SizedBox(height: 24),
            Text(
              'People with access',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              )
            else if (state.shares.isEmpty)
              Text(
                'Only you can open this note.',
                style: TextStyle(color: muted),
              )
            else
              for (final share in state.shares)
                RecipientRow(
                  key: ValueKey(share.id),
                  email: share.email,
                  name: share.displayName,
                  permission: NotePermission.fromApi(share.permission),
                  onPermissionChanged: state.busy
                      ? null
                      : (value) => _cubit.changePermission(share, value),
                  onRemove: state.busy ? null : () => _revoke(share),
                ),
          ],
        ),
      );
    },
  );
}

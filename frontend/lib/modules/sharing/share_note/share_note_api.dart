import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/note_features_api.dart';
import 'package:jotter/models/note_features.dart';
import 'package:jotter/shared/models/note_permission.dart';

class ShareNoteApi {
  ShareNoteApi(this._remote);

  final ApiNoteRepository _remote;

  Future<List<NoteShare>> list(String noteId) => _remote.listShares(noteId);

  Future<ShareInvitationResult> invite(
    String noteId,
    Map<String, NotePermission> recipients,
  ) => _remote.inviteRecipients(noteId, [
    for (final entry in recipients.entries)
      (email: entry.key, permission: entry.value.apiValue),
  ]);

  Future<void> changePermission(
    String noteId,
    String shareId,
    NotePermission permission,
  ) => _remote.changeSharePermission(noteId, shareId, permission.apiValue);

  Future<void> revoke(String noteId, String shareId) =>
      _remote.revokeShare(noteId, shareId);
}

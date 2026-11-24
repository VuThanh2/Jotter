import 'dart:typed_data';

import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/note_features_api.dart';
import 'package:jotter/models/note_features.dart';

class AttachmentsApi {
  AttachmentsApi(this._remote);

  final ApiNoteRepository _remote;

  Future<List<NoteAttachment>> list(String noteId) =>
      _remote.listAttachments(noteId);

  /// Validates size and executable signatures before sending.
  Future<void> upload(String noteId, Uint8List bytes, String fileName) =>
      _remote.attachFile(noteId, bytes, fileName);

  Future<void> remove(String attachmentId) =>
      _remote.removeAttachment(attachmentId);

  Future<Uint8List> download(String attachmentId) =>
      _remote.attachmentBytes(attachmentId);

  Uri contentUri(String attachmentId) =>
      Uri.parse('${_remote.baseUrl}/api/attachments/$attachmentId/content');

  Map<String, String> get authHeaders => {
    'Authorization': 'Bearer ${_remote.accessToken}',
  };
}

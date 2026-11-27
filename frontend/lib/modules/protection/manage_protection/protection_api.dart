import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/note_features_api.dart';

class ProtectionApi {
  ProtectionApi(this._remote);

  final ApiNoteRepository _remote;

  Future<void> enable(String noteId, String password, String confirmation) =>
      _remote.enableProtection(noteId, password, confirmation);

  Future<void> changePassword(
    String noteId,
    String current,
    String password,
    String confirmation,
  ) => _remote.changeNotePassword(noteId, current, password, confirmation);

  Future<void> disable(String noteId, String current) =>
      _remote.disableProtection(noteId, current);

  /// Ends this device's unlock session.
  Future<void> lock(String noteId) => _remote.relockNote(noteId);
}

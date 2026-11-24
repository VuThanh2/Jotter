import 'package:jotter/data/account_api.dart';
import 'package:jotter/data/api_note_repository.dart';

class ChangePasswordApi {
  ChangePasswordApi(this._remote);

  final ApiNoteRepository _remote;

  /// Other devices are signed out; this one receives a fresh bearer.
  Future<void> change({
    required String current,
    required String password,
    required String confirm,
  }) => _remote.changePassword(current, password, confirm);
}

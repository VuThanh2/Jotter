import 'package:jotter/data/account_api.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/models/jotter_account.dart';

class ActivationApi {
  ActivationApi(this._remote);

  final ApiNoteRepository _remote;

  String get email => _remote.account.email;

  /// The server issues a new bearer here, which the session stores.
  Future<JotterAccount> confirm(String code) async {
    await _remote.confirmActivation(code);
    return _remote.account;
  }

  Future<int> resend() => _remote.resendActivation();
}

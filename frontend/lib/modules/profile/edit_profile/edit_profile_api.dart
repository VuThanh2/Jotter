import 'dart:typed_data';

import 'package:jotter/data/account_api.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/models/jotter_account.dart';

class EditProfileApi {
  EditProfileApi(this._remote);

  final ApiNoteRepository _remote;

  Future<JotterAccount> rename(String displayName) =>
      _remote.updateProfile(displayName);

  Future<JotterAccount> uploadAvatar(Uint8List bytes, String fileName) async {
    await _remote.uploadAvatar(bytes, fileName);
    return _remote.account;
  }

  Future<JotterAccount> removeAvatar() async {
    await _remote.removeAvatar();
    return _remote.account;
  }
}

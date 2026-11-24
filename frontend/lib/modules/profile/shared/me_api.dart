import 'dart:typed_data';

import 'package:jotter/data/account_api.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/models/jotter_account.dart';

class MeApi {
  MeApi(this._remote);

  final ApiNoteRepository _remote;

  JotterAccount get cachedAccount => _remote.account;

  Future<JotterAccount> fetchProfile() => _remote.getProfile();

  Future<Uint8List?> fetchAvatar() => _remote.getAvatar();
}

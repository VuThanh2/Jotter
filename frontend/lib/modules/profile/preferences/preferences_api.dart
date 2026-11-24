import 'package:jotter/data/account_api.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/models/jotter_preferences.dart';

class PreferencesApi {
  PreferencesApi(this._remote);

  final ApiNoteRepository _remote;

  String get accountId => _remote.account.id;

  Future<JotterPreferences> fetch() => _remote.getPreferences();

  Future<JotterPreferences> save(JotterPreferences preferences) =>
      _remote.updatePreferences(preferences);
}

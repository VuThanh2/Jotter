import 'package:shared_preferences/shared_preferences.dart';

/// Account-scoped snapshots contain note data and durable operation IDs, never credentials.
abstract interface class WorkspaceStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class PreferencesWorkspaceStore implements WorkspaceStore {
  Future<SharedPreferences>? _preferences;
  Future<SharedPreferences> get _instance =>
      _preferences ??= SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _instance).getString(key);

  @override
  Future<void> write(String key, String value) async {
    if (!await (await _instance).setString(key, value)) {
      throw StateError('The local workspace could not be saved.');
    }
  }

  @override
  Future<void> remove(String key) async {
    if (!await (await _instance).remove(key)) {
      throw StateError('The local workspace could not be removed.');
    }
  }
}

/// An injectable store for tests and environments without durable storage.
class MemoryWorkspaceStore implements WorkspaceStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

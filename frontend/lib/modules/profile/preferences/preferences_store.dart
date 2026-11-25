import 'dart:convert';

import 'package:jotter/models/jotter_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef CachedPreferences = ({JotterPreferences preferences, bool pending});

/// Per-account cache so preferences apply at startup and survive offline edits.
class PreferencesStore {
  static String _key(String accountId) => 'jotter.preferences.v1.$accountId';

  Future<CachedPreferences?> read(String accountId) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        _key(accountId),
      );
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        preferences: JotterPreferences.fromJson(
          Map<String, dynamic>.from(json['preferences'] as Map),
        ),
        pending: json['pending'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
    String accountId,
    JotterPreferences preferences, {
    required bool pending,
  }) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        _key(accountId),
        jsonEncode({'preferences': preferences.toJson(), 'pending': pending}),
      );
    } catch (_) {
      // Preferences still apply for this session without device storage.
    }
  }
}

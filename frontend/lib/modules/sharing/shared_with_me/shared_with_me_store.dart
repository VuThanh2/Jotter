import 'dart:convert';

import 'package:jotter/data/local_workspace_store.dart';

/// Which shares this account was already told about, and which it has
/// already looked at in the Shared tab.
class ShareMarks {
  const ShareMarks({required this.announced, required this.viewed});

  final Set<String> announced;
  final Set<String> viewed;
}

class SharedWithMeStore {
  SharedWithMeStore(this._storage, {required this.accountId});

  final WorkspaceStore _storage;
  final String accountId;

  String get _key => 'jotter.shareMarks.v2.$accountId';

  /// Null on the first run for this account on this device.
  Future<ShareMarks?> read() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      Set<String> ids(String field) => {
        for (final id in json[field] as List? ?? const []) '$id',
      };
      return ShareMarks(announced: ids('announced'), viewed: ids('viewed'));
    } catch (_) {
      return null;
    }
  }

  Future<void> write(ShareMarks marks) async {
    try {
      await _storage.write(
        _key,
        jsonEncode({
          'announced': marks.announced.toList(),
          'viewed': marks.viewed.toList(),
        }),
      );
    } catch (_) {
      // Losing these marks only means a notice may be shown again.
    }
  }
}

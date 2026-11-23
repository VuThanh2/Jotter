import 'package:jotter/data/api_note_repository.dart';

class SharedNoteInfo {
  const SharedNoteInfo({
    required this.noteId,
    required this.sharedBy,
    required this.sharedAt,
    required this.canEdit,
  });

  factory SharedNoteInfo.fromJson(Map<String, dynamic> json) {
    final owner = Map<String, dynamic>.from(json['sharedBy'] as Map? ?? {});
    return SharedNoteInfo(
      noteId: json['noteId'] as String,
      sharedBy:
          owner['displayName'] as String? ?? owner['email'] as String? ?? '',
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      canEdit: json['permission'] == 'Edit',
    );
  }

  final String noteId;
  final String sharedBy;
  final DateTime sharedAt;
  final bool canEdit;
}

class SharedWithMeApi {
  SharedWithMeApi(this._remote);

  final ApiNoteRepository _remote;

  Future<Map<String, SharedNoteInfo>> fetch() async {
    final result = <String, SharedNoteInfo>{};
    String? cursor;
    do {
      final page = await _remote.request(
        'GET',
        '/api/shared-with-me',
        query: {'limit': '100', 'cursor': ?cursor},
      );
      for (final item in page['items'] as List? ?? const []) {
        final info = SharedNoteInfo.fromJson(Map<String, dynamic>.from(item));
        result[info.noteId] = info;
      }
      cursor = page['nextCursor'] as String?;
    } while (cursor != null);
    return result;
  }
}

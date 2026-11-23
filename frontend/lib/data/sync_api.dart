import 'api_note_repository.dart';

extension WorkspaceSyncApi on ApiNoteRepository {
  Future<Map<String, dynamic>> pullChanges({required int since}) =>
      request('GET', '/api/sync', query: {'since': '$since', 'limit': '200'});

  Future<int> getNoteVersion(String noteId) async {
    final result = await request('GET', '/api/notes/$noteId/version');
    return (result['version'] as num).toInt();
  }

  Future<Uri> issueRealtimeConnectionUri() async {
    final result = await request('POST', '/api/realtime/token');
    final base = Uri.parse(baseUrl);
    final prefix = base.path.replaceFirst(RegExp(r'/+$'), '');
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '$prefix/ws',
      queryParameters: {'token': result['token'] as String},
    );
  }
}

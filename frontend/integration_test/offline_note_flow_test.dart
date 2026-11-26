import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/local_workspace_store.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/models/jotter_note.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline draft survives reopening and syncs on reconnect', (
    tester,
  ) async {
    var online = false;
    var created = false;
    final keys = <String>[];
    final store = MemoryWorkspaceStore();
    const date = '2026-10-28T08:00:00Z';
    final remote = ApiNoteRepository.fromSession(
      baseUrl: 'https://example.test',
      session: {
        'accessToken': 'test',
        'user': {
          'userId': 'owner',
          'email': 'owner@example.test',
          'displayName': 'Owner',
          'isActivated': true,
        },
      },
      client: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/notes') {
          keys.add(request.headers['Idempotency-Key']!);
          if (!online) throw http.ClientException('offline');
          expect(jsonDecode(request.body)['content'], 'offline text');
          created = true;
          return http.Response(
            jsonEncode({
              'noteId': 'draft',
              'version': 1,
              'createdAt': date,
              'updatedAt': date,
            }),
            200,
          );
        }
        if (!online) throw http.ClientException('offline');
        return http.Response(
          jsonEncode({
            'notes': created
                ? [
                    {
                      'noteId': 'draft',
                      'ownerId': 'owner',
                      'title': 'Draft',
                      'content': 'offline text',
                      'isPinned': false,
                      'isProtected': false,
                      'labelIds': [],
                      'permission': 'Owner',
                      'version': 1,
                      'changeSeq': 1,
                      'createdAt': date,
                      'updatedAt': date,
                      'deletedAt': null,
                    },
                  ]
                : [],
            'labels': [],
            'shares': [],
            'attachments': [],
            'nextChangeSeq': 1,
            'hasMore': false,
            'fullResyncRequired': false,
          }),
          200,
        );
      }),
    );
    Future<OfflineNoteRepository> open() => OfflineNoteRepository.open(
      remote,
      store: store,
      enableRealtime: false,
      startBackground: false,
    );
    final first = await open();
    await first.saveNote(
      JotterNote(
        id: 'draft',
        title: 'Draft',
        content: 'offline text',
        createdAt: DateTime.parse(date),
        updatedAt: DateTime.parse(date),
      ),
      isNew: true,
    );
    expect(first.pendingChanges, hasLength(1));
    await first.dispose(disposeRemote: false);
    final second = await open();
    expect(second.cachedNotes.single.content, 'offline text');
    online = true;
    await second.synchronize();
    expect(second.pendingChanges, isEmpty);
    expect(second.cachedNotes.single.version, 1);
    expect(keys, [keys.first, keys.first]);
    await second.dispose();
  });
}

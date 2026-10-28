import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/local_workspace_store.dart';
import 'package:jotter/data/offline_note_repository.dart';

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('real socket sends scoped token/join/leave and consumes presence, permission and revocation', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final joined = Completer<Map<String, dynamic>>();
    final left = Completer<Map<String, dynamic>>();
    final disconnected = Completer<void>();
    WebSocket? serverSocket;
    final serverRequests = <String>[];
    final serverSubscription = server.listen((request) async {
      serverRequests.add(request.uri.toString());
      if (request.uri.path != '/ws' ||
          request.uri.queryParameters['token'] != 'short-lived-ws-token') {
        request.response.statusCode = 403;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      serverSocket = socket;
      socket.listen(
        (dynamic raw) {
          final message = Map<String, dynamic>.from(
            jsonDecode(raw as String) as Map,
          );
          if (message['type'] == 'join' && !joined.isCompleted) {
            joined.complete(message);
          }
          if (message['type'] == 'leave' && !left.isCompleted) {
            left.complete(message);
          }
        },
        onDone: () {
          if (!disconnected.isCompleted) disconnected.complete();
        },
      );
    });
    var tokenRequests = 0;
    var permission = 'Edit';
    var revoked = false;
    final remote = await ApiNoteRepository.signIn(
      baseUrl: 'http://127.0.0.1:${server.port}',
      email: 'viewer@example.test',
      password: 'test-password',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/auth/login':
            return _json({
              'accessToken': 'rest-only-token',
              'user': {
                'userId': 'viewer',
                'email': 'viewer@example.test',
                'displayName': 'Viewer',
                'isActivated': true,
              },
            });
          case '/api/realtime/token':
            tokenRequests++;
            expect(request.headers['Authorization'], 'Bearer rest-only-token');
            return _json({
              'token': 'short-lived-ws-token',
              'expiresAt': '2030-01-01T00:00:00Z',
            });
          case '/api/sync':
            return _json({
              'notes': revoked
                  ? []
                  : [
                      {
                        'noteId': 'shared-note',
                        'ownerId': 'other-owner',
                        'title': 'Shared note',
                        'content': 'PRIVATE SHARED BODY',
                        'version': 1,
                        'isPinned': null,
                        'isProtected': false,
                        'labelIds': null,
                        'permission': permission,
                        'createdAt': '2026-10-28T08:00:00Z',
                        'updatedAt': '2026-10-28T08:00:00Z',
                        'deletedAt': null,
                      },
                    ],
              'labels': [],
              'attachments': [],
              'shares': [
                {
                  'shareId': 'grant',
                  'noteId': 'shared-note',
                  'recipientUserId': 'viewer',
                  'permission': permission,
                  'revokedAt': revoked ? '2026-10-28T09:00:00Z' : null,
                },
              ],
              'nextChangeSeq': revoked
                  ? 3
                  : permission == 'ReadOnly'
                  ? 2
                  : 1,
              'hasMore': false,
              'fullResyncRequired': false,
            });
          default:
            throw StateError('Unexpected HTTP path ${request.url.path}');
        }
      }),
    );
    final store = MemoryWorkspaceStore();
    final repository = await OfflineNoteRepository.open(
      remote,
      store: store,
      startBackground: false,
    );
    final presence = Completer<Map<String, dynamic>>();
    final permissionChanged = Completer<void>();
    final accessRevoked = Completer<void>();
    final events = repository.realtimeEvents.listen((event) {
      if (event['type'] == 'presence' && !presence.isCompleted) {
        presence.complete(event);
      }
      if (event['type'] == 'permissionChanged' &&
          !permissionChanged.isCompleted) {
        permissionChanged.complete();
      }
      if (event['type'] == 'accessRevoked' && !accessRevoked.isCompleted) {
        accessRevoked.complete();
      }
    });
    try {
      await repository.synchronize();
      expect(repository.cachedNotes.single.content, 'PRIVATE SHARED BODY');
      expect(repository.cachedNotes.single.canEdit, true);
      await repository.watchNote('shared-note');
      expect(await joined.future.timeout(const Duration(seconds: 5)), {
        'type': 'join',
        'noteId': 'shared-note',
      });
      expect(tokenRequests, 1);
      expect(serverRequests.single, '/ws?token=short-lived-ws-token');
      expect(repository.syncStatus.value.realtimeConnected, true);
      serverSocket!.add(
        jsonEncode({
          'type': 'presence',
          'noteId': 'shared-note',
          'users': [
            {'userId': 'friend', 'displayName': 'A teammate'},
          ],
        }),
      );
      final presenceEvent = await presence.future.timeout(
        const Duration(seconds: 5),
      );
      expect(
        (presenceEvent['users'] as List).single['displayName'],
        'A teammate',
      );

      permission = 'ReadOnly';
      serverSocket!.add(
        jsonEncode({
          'type': 'permissionChanged',
          'noteId': 'shared-note',
          'permission': permission,
        }),
      );
      await permissionChanged.future.timeout(const Duration(seconds: 5));
      expect(repository.cachedNotes.single.canEdit, false);

      revoked = true;
      serverSocket!.add(
        jsonEncode({'type': 'accessRevoked', 'noteId': 'shared-note'}),
      );
      await accessRevoked.future.timeout(const Duration(seconds: 5));
      expect(repository.cachedNotes, isEmpty);
      await repository.synchronize();
      expect(
        store.values[repository.storageKey],
        isNot(contains('PRIVATE SHARED BODY')),
      );
      expect(
        store.values[repository.storageKey],
        isNot(contains('rest-only-token')),
      );

      await repository.watchNote(null);
      expect(await left.future.timeout(const Duration(seconds: 5)), {
        'type': 'leave',
        'noteId': 'shared-note',
      });
      await repository.dispose();
      await disconnected.future.timeout(const Duration(seconds: 5));
    } finally {
      await events.cancel();
      await repository.dispose();
      await serverSocket?.close();
      await serverSubscription.cancel();
      await server.close(force: true);
    }
  });
}

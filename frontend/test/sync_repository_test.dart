import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/local_workspace_store.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/data/offline_note_repository.dart';
import 'package:jotter/models/jotter_note.dart';

const _date = '2026-10-28T08:00:00Z';
const _owner = 'signed-in-owner';

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

Future<ApiNoteRepository> _remote(
  Future<http.Response> Function(http.Request) handler, {
  String owner = _owner,
}) => ApiNoteRepository.signIn(
  baseUrl: 'https://jotter.example',
  email: '$owner@example.test',
  password: 'example',
  client: MockClient((request) async {
    if (request.url.path == '/api/auth/login')
      return _json({
        'accessToken': 'never-persist-this-token',
        'expiresAt': '2030-01-01T00:00:00Z',
        'user': {
          'userId': owner,
          'email': '$owner@example.test',
          'displayName': 'Test account',
          'isActivated': true,
        },
      });
    if (request.url.path == '/api/auth/logout') return http.Response('', 204);
    return handler(request);
  }),
);

Map<String, dynamic> _syncNote(
  String id, {
  String content = 'A complete owned note.',
  bool owned = true,
  bool protected = false,
  int version = 1,
  int seq = 1,
}) => {
  'noteId': id,
  'ownerId': owned ? _owner : 'other-owner',
  'title': 'Note $id',
  'content': protected ? null : content,
  'isPinned': owned ? false : null,
  'isProtected': protected,
  'labelIds': owned ? <String>[] : null,
  'permission': owned ? 'Owner' : 'Edit',
  'version': version,
  'changeSeq': seq,
  'createdAt': _date,
  'updatedAt': _date,
  'deletedAt': null,
};

Map<String, dynamic> _page({
  List<Map<String, dynamic>> notes = const [],
  List<Map<String, dynamic>> labels = const [],
  List<Map<String, dynamic>> shares = const [],
  int next = 0,
  bool more = false,
  bool reset = false,
}) => {
  'notes': notes,
  'labels': labels,
  'shares': shares,
  'attachments': [],
  'nextChangeSeq': next,
  'hasMore': more,
  'fullResyncRequired': reset,
};

JotterNote _draft(
  String id, {
  String content = 'A local draft.',
  int version = 0,
}) => JotterNote(
  id: id,
  title: 'Draft $id',
  content: content,
  createdAt: DateTime.parse(_date),
  updatedAt: DateTime.parse(_date),
  version: version,
);

Future<OfflineNoteRepository> _open(
  ApiNoteRepository remote,
  MemoryWorkspaceStore store,
) => OfflineNoteRepository.open(
  remote,
  store: store,
  enableRealtime: false,
  startBackground: false,
);

void main() {
  test(
    'sync persists owned bodies but never tokens, protected or shared bodies',
    () async {
      final store = MemoryWorkspaceStore();
      final remote = await _remote((request) async {
        expect(request.url.path, '/api/sync');
        return _json(
          _page(
            notes: [
              _syncNote('own', content: 'OWN BODY IS AVAILABLE OFFLINE'),
              _syncNote(
                'shared',
                content: 'SHARED BODY MUST STAY IN MEMORY',
                owned: false,
              ),
              _syncNote('secret', protected: true),
            ],
            next: 3,
          ),
        );
      });
      final repository = await _open(remote, store);
      await repository.synchronize();
      expect(repository.cachedNotes, hasLength(3));
      expect(
        repository.cachedNotes
            .singleWhere((note) => note.id == 'shared')
            .content,
        contains('SHARED BODY'),
      );
      final snapshot = store.values[repository.storageKey]!;
      expect(snapshot, contains('OWN BODY IS AVAILABLE OFFLINE'));
      expect(snapshot, isNot(contains('SHARED BODY MUST STAY IN MEMORY')));
      expect(snapshot, isNot(contains('never-persist-this-token')));
      final restored = jsonDecode(snapshot) as Map<String, dynamic>;
      final savedNotes = restored['notes'] as List;
      final protected = savedNotes.singleWhere(
        (dynamic note) => note['id'] == 'secret',
      ) as Map;
      expect(protected['content'], isEmpty);
      expect(protected['contentLoaded'], false);
      await repository.dispose();
    },
  );

  test(
    'owned draft survives restart and retries with its durable idempotency key',
    () async {
      final store = MemoryWorkspaceStore();
      var online = false;
      final keys = <String>[];
      var created = false;
      Future<http.Response> handler(http.Request request) async {
        if (request.method == 'POST' && request.url.path == '/api/notes') {
          keys.add(request.headers['Idempotency-Key']!);
          if (!online) throw http.ClientException('offline');
          created = true;
          expect(jsonDecode(request.body)['content'], 'A local draft.');
          return _json({
            'noteId': 'draft-id',
            'version': 1,
            'createdAt': _date,
            'updatedAt': _date,
          });
        }
        if (!online) throw http.ClientException('offline');
        return _json(
          _page(
            notes: created
                ? [_syncNote('draft-id', content: 'A local draft.')]
                : [],
            next: 1,
          ),
        );
      }

      final first = await _open(await _remote(handler), store);
      final savedOffline = await first.saveNote(
        _draft('draft-id'),
        isNew: true,
      );
      expect(savedOffline.content, 'A local draft.');
      expect(first.syncStatus.value.isOffline, true);
      expect(first.pendingChanges, hasLength(1));
      final key = keys.single;
      await first.dispose();

      final second = await _open(await _remote(handler), store);
      expect(second.cachedNotes.single.content, 'A local draft.');
      expect(second.pendingChanges.single.id, key);
      online = true;
      await second.synchronize();
      expect(keys, [key, key]);
      expect(second.pendingChanges, isEmpty);
      expect(second.cachedNotes.single.version, 1);
      await second.dispose();
    },
  );

  test('multiple offline revisions rebase only on earlier successful queued writes', () async {
    final store = MemoryWorkspaceStore();
    var online = false;
    final versions = <int>[];
    var serverVersion = 3;
    var serverContent = 'Original server content';
    final remote = await _remote((request) async {
      if (!online) throw http.ClientException('offline');
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map;
        versions.add(body['baseVersion'] as int);
        expect(body['baseVersion'], serverVersion);
        serverVersion++;
        serverContent = body['content'] as String;
        return _json({'version': serverVersion, 'updatedAt': _date});
      }
      return _json(
        _page(
          notes: [
            _syncNote(
              'existing',
              content: serverContent,
              version: serverVersion,
            ),
          ],
          next: serverVersion,
        ),
      );
    });
    final repository = await _open(remote, store);
    await repository.saveNote(
      _draft('existing', version: 3, content: 'First local revision'),
    );
    final second = await repository.saveNote(
      _draft('existing', version: 3, content: 'Second local revision'),
    );
    expect(second.version, 3);
    expect(repository.pendingChanges, hasLength(2));
    online = true;
    await repository.synchronize();
    expect(versions, [3, 4]);
    expect(repository.cachedNotes.single.content, 'Second local revision');
    expect(repository.cachedNotes.single.version, 5);
    expect(repository.pendingChanges, isEmpty);
    await repository.dispose();
  });

  test('version conflict preserves draft and creates a server-linked conflict copy', () async {
    final store = MemoryWorkspaceStore();
    Map<String, dynamic>? copyBody;
    final remote = await _remote((request) async {
      if (request.method == 'PUT')
        return _json({
          'code': 'VersionConflict',
          'title': 'Server note changed',
          'serverNote': {
            'title': 'Server title',
            'content': 'Server text',
            'version': 8,
          },
        }, 409);
      if (request.method == 'POST') {
        copyBody = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        return _json({'version': 1, 'createdAt': _date, 'updatedAt': _date});
      }
      final notes = [
        _syncNote('conflicting', content: 'Server text', version: 8),
      ];
      if (copyBody != null)
        notes.add(
          _syncNote(
            copyBody!['noteId'] as String,
            content: copyBody!['content'] as String,
          ),
        );
      return _json(_page(notes: notes, next: 8));
    });
    final repository = await _open(remote, store);
    await expectLater(
      repository.saveNote(
        _draft('conflicting', version: 2, content: 'KEEP THIS DRAFT'),
      ),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          'VersionConflict',
        ),
      ),
    );
    final change = repository.pendingChanges.single;
    expect(change.isConflict, true);
    expect(repository.cachedNotes.single.content, 'KEEP THIS DRAFT');
    expect(repository.pendingDraft(change.id)!.content, 'KEEP THIS DRAFT');
    final copy = await repository.recoverConflictAsCopy(change.id);
    expect(copyBody!['conflictOfNoteId'], 'conflicting');
    expect(copyBody!['content'], 'KEEP THIS DRAFT');
    expect(copy.id, isNot('conflicting'));
    expect(repository.pendingChanges, isEmpty);
    await repository.dispose();
  });

  test(
    'cursor expiry reloads from zero and revocation removes cached shared note',
    () async {
      final store = MemoryWorkspaceStore();
      var step = 0;
      final cursors = <int>[];
      final remote = await _remote((request) async {
        final cursor = int.parse(request.url.queryParameters['since']!);
        cursors.add(cursor);
        switch (step++) {
          case 0:
            return _json(
              _page(notes: [_syncNote('shared', owned: false)], next: 50),
            );
          case 1:
            return _json(_page(reset: true));
          default:
            return _json(
              _page(
                shares: [
                  {
                    'shareId': 'grant',
                    'noteId': 'shared',
                    'recipientUserId': _owner,
                    'revokedAt': _date,
                  },
                ],
                next: 60,
              ),
            );
        }
      });
      final repository = await _open(remote, store);
      await repository.synchronize();
      expect(repository.cachedNotes, hasLength(1));
      await repository.synchronize();
      expect(cursors, [0, 50, 0]);
      expect(repository.cachedNotes, isEmpty);
      expect(
        store.values[repository.storageKey],
        isNot(contains('"id":"shared"')),
      );
      await repository.dispose();
    },
  );

  test('new remote protection scrubs disk while keeping a queued draft in session memory', () async {
    final store = MemoryWorkspaceStore();
    var phase = 0;
    final remote = await _remote((request) async {
      if (request.method == 'PUT')
        return _json({'code': 'NoteLocked', 'title': 'Locked'}, 423);
      return _json(
        _page(
          notes: [_syncNote('protected-now', protected: phase > 0)],
          next: ++phase,
        ),
      );
    });
    final repository = await _open(remote, store);
    final events = <Map<String,dynamic>>[];
    final subscription = repository.realtimeEvents.listen(events.add);
    await repository.synchronize();
    await expectLater(
      repository.saveNote(
        _draft('protected-now', version: 1, content: 'UNSENT PRIVATE DRAFT'),
      ),
      throwsA(isA<RepositoryException>()),
    );
    expect(repository.cachedNotes.single.isProtected, true);
    expect(repository.cachedNotes.single.content, isEmpty);
    final issue = repository.pendingChanges.single;
    expect(issue.code, 'ProtectedDraft');
    expect(repository.pendingDraft(issue.id)!.content, 'UNSENT PRIVATE DRAFT');
    expect(
      store.values[repository.storageKey],
      isNot(contains('UNSENT PRIVATE DRAFT')),
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.any((event) => event['type'] == 'accessRevoked' && event['noteId'] == 'protected-now' && event['isProtected'] == true), true);
    await subscription.cancel();
    await repository.dispose();
  });

  test('conflict recovery keeps the freshest dependent offline revision', () async {
    final store = MemoryWorkspaceStore();
    var online = false;
    Map<String,dynamic>? copyBody;
    final remote = await _remote((request) async {
      if (!online) throw http.ClientException('offline');
      if (request.method == 'PUT') return _json({'code': 'VersionConflict', 'title': 'Changed elsewhere'}, 409);
      if (request.method == 'POST') {
        copyBody = Map<String,dynamic>.from(jsonDecode(request.body) as Map);
        return _json({'version': 1, 'createdAt': _date, 'updatedAt': _date});
      }
      final notes = [_syncNote('original', content: 'Latest server note', version: 8)];
      if (copyBody != null) notes.add(_syncNote(copyBody!['noteId'] as String, content: copyBody!['content'] as String));
      return _json(_page(notes: notes, next: 8));
    });
    final repository = await _open(remote, store);
    await repository.saveNote(_draft('original', content: 'First offline revision', version: 2));
    await repository.saveNote(_draft('original', content: 'Newest offline revision', version: 2));
    online = true;
    await repository.synchronize();
    final firstConflict = repository.pendingChanges.first;
    await repository.recoverConflictAsCopy(firstConflict.id);
    expect(copyBody!['content'], 'Newest offline revision');
    expect(copyBody!['conflictOfNoteId'], 'original');
    expect(repository.pendingChanges, isEmpty);
    await repository.dispose();
  });

  test(
    'offline protected/shared content cannot be read from the local cache',
    () async {
      final store = MemoryWorkspaceStore();
      var online = true;
      final remote = await _remote((request) async {
        if (!online) throw http.ClientException('offline');
        if (request.url.path == '/api/sync')
          return _json(
            _page(
              notes: [
                _syncNote('shared', owned: false),
                _syncNote('locked', protected: true),
              ],
              next: 2,
            ),
          );
        return _json({'code': 'NoteLocked', 'title': 'Locked'}, 423);
      });
      final repository = await _open(remote, store);
      await repository.synchronize();
      online = false;
      await expectLater(
        repository.getNote('shared'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            'NetworkUnavailable',
          ),
        ),
      );
      await expectLater(
        repository.getNote('locked'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            'NetworkUnavailable',
          ),
        ),
      );
      await repository.dispose();
    },
  );

  test('explicit sign-out clears only the signed-in account cache', () async {
    final store = MemoryWorkspaceStore();
    final first = await _open(
      await _remote((_) async => _json(_page()), owner: 'one'),
      store,
    );
    final second = await _open(
      await _remote((_) async => _json(_page()), owner: 'two'),
      store,
    );
    await first.synchronize();
    await second.synchronize();
    expect(
      store.values.keys,
      containsAll([first.storageKey, second.storageKey]),
    );
    await first.close();
    expect(store.values.containsKey(first.storageKey), false);
    expect(store.values.containsKey(second.storageKey), true);
    await second.dispose();
  });
}

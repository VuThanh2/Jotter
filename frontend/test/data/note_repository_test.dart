import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/data/preview_note_repository.dart';
import 'package:jotter/models/jotter_note.dart';

const _server = 'http://localhost:5080';
const _owner = 'owner-id';
const _date = '2026-10-28T08:00:00Z';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _session() => _json({
  'accessToken': 'test-access-token',
  'expiresAt': '2026-10-28T09:00:00Z',
  'user': {
    'userId': _owner,
    'email': 'reader@example.com',
    'displayName': 'Alex Reader',
    'isActivated': true,
    'avatarUrl': null,
  },
});

Future<ApiNoteRepository> _signIn(
  Future<http.Response> Function(http.Request request) handler,
) => ApiNoteRepository.signIn(
  baseUrl: _server,
  email: 'reader@example.com',
  password: 'example-password',
  client: MockClient((request) async {
    if (request.url.path == '/api/auth/login') return _session();
    return handler(request);
  }),
);

Map<String, dynamic> _listedNote(
  String id, {
  bool owned = true,
  bool protected = false,
}) => {
  'noteId': id,
  'title': 'A useful thought',
  'preview': protected ? '' : 'Only the first part of the content',
  'version': 3,
  'isPinned': owned ? false : null,
  'isProtected': protected,
  'isShared': !owned,
  'labelIds': owned ? <String>[] : null,
  'updatedAt': _date,
};

Map<String, dynamic> _detail(
  String id, {
  String permission = 'Owner',
  bool protected = false,
}) => {
  'noteId': id,
  'ownerId': permission == 'Owner' ? _owner : 'someone-else',
  'title': 'A useful thought',
  'content': 'The complete note content, not a truncated preview.',
  'version': 3,
  'isPinned': permission == 'Owner' ? false : null,
  'isProtected': protected,
  'labelIds': permission == 'Owner' ? <String>[] : null,
  'createdAt': _date,
  'updatedAt': _date,
  'permission': permission,
};

JotterNote _draft({String? id}) => JotterNote(
  id: id ?? generateUuid(),
  title: 'A fresh idea',
  content: 'Keep the entire draft safe.',
  updatedAt: DateTime.parse(_date),
  createdAt: DateTime.parse(_date),
);

void main() {
  group('API repository', () {
    test('forwards full-content search to every API page', () async {
      var page = 0;
      final repository = await _signIn((request) async {
        expect(request.url.queryParameters['q'], 'café & creative ideas');
        expect(request.url.queryParameters['scope'], 'All');
        expect(
          request.url.queryParameters['cursor'],
          page == 0 ? null : 'next',
        );
        page++;
        return _json({
          'items': [_listedNote('result-$page')],
          'nextCursor': page == 1 ? 'next' : null,
        });
      });
      final notes = await repository.listNotes(
        query: '  café & creative ideas  ',
      );
      expect(notes, hasLength(2));
      expect(page, 2);
    });

    test(
      'reuses label ID and operation key when a create is retried',
      () async {
        final requests = <http.Request>[];
        final repository = await _signIn((request) async {
          requests.add(request);
          expect(request.url.path, '/api/labels');
          expect(request.method, 'POST');
          if (requests.length == 1) {
            return _json({
              'code': 'Unavailable',
              'title': 'Please retry.',
            }, 503);
          }
          return _json(jsonDecode(request.body) as Map<String, dynamic>, 201);
        });
        await expectLater(
          repository.createLabel('  Reading  '),
          throwsA(isA<RepositoryException>()),
        );
        final label = await repository.createLabel('Reading');
        expect(label.name, 'Reading');
        expect(requests.first.body, requests.last.body);
        expect(label.id, jsonDecode(requests.first.body)['labelId']);
        expect(
          requests.first.headers['idempotency-key'],
          requests.last.headers['idempotency-key'],
        );
      },
    );

    test(
      'signs in without a bearer and keeps account data in memory',
      () async {
        var calls = 0;
        final repository = await ApiNoteRepository.signIn(
          baseUrl: '$_server/',
          email: ' reader@example.com ',
          password: 'my password',
          client: MockClient((request) async {
            calls++;
            expect(request.method, 'POST');
            expect(request.url.toString(), '$_server/api/auth/login');
            expect(request.headers['authorization'], isNull);
            expect(jsonDecode(request.body), {
              'email': 'reader@example.com',
              'password': 'my password',
            });
            return _session();
          }),
        );
        expect(calls, 1);
        expect(repository.account.id, _owner);
        expect(repository.account.email, 'reader@example.com');
        expect(repository.account.displayName, 'Alex Reader');
        expect(repository.isPreview, isFalse);
      },
    );

    test(
      'loads every All-scope page with a bearer and leaves previews unloaded',
      () async {
        final cursors = <String?>[];
        final repository = await _signIn((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/notes');
          expect(request.headers['authorization'], 'Bearer test-access-token');
          expect(request.url.queryParameters['scope'], 'All');
          expect(request.url.queryParameters['limit'], '100');
          final cursor = request.url.queryParameters['cursor'];
          cursors.add(cursor);
          return _json({
            'items': [
              if (cursor == null)
                _listedNote('owned')
              else
                _listedNote('shared', owned: false),
            ],
            'nextCursor': cursor == null ? 'page+two/=' : null,
          });
        });
        final notes = await repository.listNotes();
        expect(cursors, [null, 'page+two/=']);
        expect(notes.map((note) => note.id), ['owned', 'shared']);
        expect(notes.first.content, isEmpty);
        expect(notes.first.contentLoaded, isFalse);
        expect(notes.first.preview, isNotEmpty);
        expect(notes.last.isOwned, isFalse);
        expect(notes.last.canEdit, isFalse);
        expect(notes.last.labelIds, isEmpty);
        await expectLater(
          repository.saveNote(notes.first.copyWith(title: 'A new title')),
          throwsA(
            isA<RepositoryException>().having(
              (error) => error.message,
              'load guard',
              contains('complete note'),
            ),
          ),
        );
      },
    );

    test(
      'creates with a client UUID then updates using the returned base version',
      () async {
        final requests = <http.Request>[];
        final repository = await _signIn((request) async {
          requests.add(request);
          final create = request.method == 'POST';
          return _json({
            'noteId': 'my-note',
            'version': create ? 1 : 2,
            'createdAt': _date,
            'updatedAt': _date,
          }, create ? 201 : 200);
        });
        final draft = _draft(id: 'my-note');
        final created = await repository.saveNote(draft, isNew: true);
        final updated = await repository.saveNote(
          created.copyWith(title: 'Revised idea'),
        );
        expect(requests.first.url.path, '/api/notes');
        expect(jsonDecode(requests.first.body), {
          'noteId': 'my-note',
          'conflictOfNoteId': null,
          'title': draft.title,
          'content': draft.content,
        });
        expect(requests.last.method, 'PUT');
        expect(requests.last.url.path, '/api/notes/my-note');
        expect(jsonDecode(requests.last.body), {
          'baseVersion': 1,
          'title': 'Revised idea',
          'content': draft.content,
        });
        for (final request in requests) {
          expect(
            request.headers['idempotency-key'],
            matches(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          );
        }
        expect(
          requests.first.headers['idempotency-key'],
          isNot(requests.last.headers['idempotency-key']),
        );
        expect(updated.version, 2);
        expect(updated.contentLoaded, isTrue);
        expect(draft.version, 0);
        expect(draft.title, 'A fresh idea');
      },
    );

    test(
      'reuses an operation key after a failed request so retry is safe',
      () async {
        final keys = <String?>[];
        final repository = await _signIn((request) async {
          keys.add(request.headers['idempotency-key']);
          if (keys.length == 1) {
            return _json({
              'code': 'Unavailable',
              'title': 'Try again shortly.',
            }, 503);
          }
          return _json({
            'version': 1,
            'createdAt': _date,
            'updatedAt': _date,
          }, 201);
        });
        final draft = _draft();
        await expectLater(
          repository.saveNote(draft, isNew: true),
          throwsA(isA<RepositoryException>()),
        );
        final result = await repository.saveNote(draft, isNew: true);
        expect(keys, hasLength(2));
        expect(keys.first, isNotNull);
        expect(keys.first, keys.last);
        expect(result.version, 1);
      },
    );

    test(
      'a version conflict preserves the caller draft and explains recovery',
      () async {
        final repository = await _signIn(
          (request) async => _json({
            'code': 'VersionConflict',
            'title': 'A newer version exists.',
            'serverNote': {
              'title': 'A different server title',
              'content': 'Server text',
              'version': 8,
            },
          }, 409),
        );
        final draft = _draft().copyWith(version: 7);
        await expectLater(
          repository.saveNote(draft),
          throwsA(
            isA<RepositoryException>()
                .having((error) => error.statusCode, 'status', 409)
                .having((error) => error.code, 'code', 'VersionConflict')
                .having(
                  (error) => error.message,
                  'recovery message',
                  contains('draft is still here'),
                ),
          ),
        );
        expect(draft.title, 'A fresh idea');
        expect(draft.content, 'Keep the entire draft safe.');
        expect(draft.version, 7);
      },
    );

    test(
      'locked notes require password unlock and a fresh detail request',
      () async {
        var unlocked = false;
        var detailRequests = 0;
        final repository = await _signIn((request) async {
          expect(request.headers['authorization'], 'Bearer test-access-token');
          if (request.url.path.endsWith('/unlock')) {
            expect(request.method, 'POST');
            expect(jsonDecode(request.body), {'password': '1234'});
            unlocked = true;
            return _json({'unlockSessionId': 'unlock-id', 'expiresAt': _date});
          }
          detailRequests++;
          if (!unlocked) {
            return _json({
              'code': 'NoteLocked',
              'title': 'Locked',
              'note': _listedNote('secret', protected: true),
            }, 423);
          }
          return _json(_detail('secret', protected: true));
        });
        await expectLater(
          repository.getNote('secret'),
          throwsA(
            isA<RepositoryException>().having(
              (error) => error.statusCode,
              'status',
              423,
            ),
          ),
        );
        final note = await repository.unlockNote('secret', '1234');
        expect(detailRequests, 2);
        expect(note.contentLoaded, isTrue);
        expect(note.content, contains('complete note content'));
        expect(note.isProtected, isTrue);
        expect(note.preview, isEmpty);
      },
    );

    test('shared read-only notes cannot be saved or organized', () async {
      var calls = 0;
      final repository = await _signIn((request) async {
        calls++;
        return _json(_detail('shared', permission: 'ReadOnly'));
      });
      final note = await repository.getNote('shared');
      expect(note.isOwned, isFalse);
      expect(note.isShared, isTrue);
      expect(note.canEdit, isFalse);
      await expectLater(
        repository.saveNote(note.copyWith(content: 'Edited')),
        throwsA(isA<RepositoryException>()),
      );
      await expectLater(
        repository.pinNote(note, true),
        throwsA(isA<RepositoryException>()),
      );
      await expectLater(
        repository.setLabels(note, ['label']),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        calls,
        1,
        reason: 'Disallowed mutations must not reach the server.',
      );
    });

    test(
      'shared edit permission permits content edits but not owner organization',
      () async {
        final repository = await _signIn((request) async {
          if (request.method == 'GET') {
            return _json(_detail('shared', permission: 'Edit'));
          }
          expect(jsonDecode(request.body)['baseVersion'], 3);
          return _json({'version': 4, 'updatedAt': _date});
        });
        final note = await repository.getNote('shared');
        expect(note.canEdit, isTrue);
        expect(note.isOwned, isFalse);
        final saved = await repository.saveNote(
          note.copyWith(content: 'A collaborative edit'),
        );
        expect(saved.version, 4);
        await expectLater(
          repository.pinNote(saved, true),
          throwsA(isA<RepositoryException>()),
        );
      },
    );
  });

  group('preview workspace', () {
    test(
      'searches complete content past the preview and respects protection',
      () async {
        final repository = PreviewNoteRepository();
        final draft = _draft().copyWith(
          title: 'A violet comet notebook',
          content: '${'x' * 240} A distinctive NEEDLE at the end.',
        );
        final note = await repository.saveNote(draft, isNew: true);
        expect(note.preview.toLowerCase(), isNot(contains('needle')));
        final results = await repository.listNotes(query: '  NeEdLe  ');
        expect(results.map((result) => result.id), [note.id]);
        final protected = await repository.saveNote(
          note.copyWith(isProtected: true),
        );
        expect(protected.preview, isEmpty);
        expect(await repository.listNotes(query: 'needle'), isEmpty);
        expect(
          (await repository.listNotes(query: 'VIOLET COMET')).single.id,
          note.id,
        );
      },
    );

    test('supports create, update, conflict detection and deletion without a server', () async {
      final repository = PreviewNoteRepository();
      final before = await repository.listNotes();
      expect(repository.isPreview, isTrue);
      expect(before, hasLength(6));
      expect(before.where((note) => note.isPinned), hasLength(2));
      final draft = _draft();
      final created = await repository.saveNote(draft, isNew: true);
      expect(created.version, 1);
      expect(await repository.listNotes(), hasLength(7));
      final updated = await repository.saveNote(
        created.copyWith(content: 'The second draft'),
      );
      expect(updated.version, 2);
      await expectLater(
        repository.saveNote(created.copyWith(content: 'Stale draft')),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            'VersionConflict',
          ),
        ),
      );
      expect((await repository.getNote(draft.id)).content, 'The second draft');
      await repository.deleteNote(draft.id);
      await expectLater(
        repository.getNote(draft.id),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.statusCode,
            'status',
            404,
          ),
        ),
      );
    });

    test('pins and labels preserve content version and enforce immutable label lists', () async {
      final repository = PreviewNoteRepository();
      final note = (await repository.listNotes()).last;
      final label = await repository.createLabel('  Reading  ');
      expect(label.name, 'Reading');
      final labeled = await repository.setLabels(note, [label.id]);
      final pinned = await repository.pinNote(labeled, true);
      expect(pinned.version, note.version);
      expect(pinned.content, note.content);
      expect(pinned.labelIds, [label.id]);
      expect(pinned.isPinned, isTrue);
      expect(() => pinned.labelIds.add('unexpected'), throwsUnsupportedError);
      await expectLater(
        repository.createLabel('reading'),
        throwsA(isA<RepositoryException>()),
      );
      await expectLater(
        repository.setLabels(pinned, ['missing']),
        throwsA(isA<RepositoryException>()),
      );
    });

    test(
      'rejects blank and oversized content and discards data when closed',
      () async {
        final repository = PreviewNoteRepository();
        await expectLater(
          repository.saveNote(
            _draft().copyWith(title: ' ', content: ''),
            isNew: true,
          ),
          throwsA(isA<RepositoryException>()),
        );
        await expectLater(
          repository.saveNote(
            _draft().copyWith(content: 'x' * 50001),
            isNew: true,
          ),
          throwsA(isA<RepositoryException>()),
        );
        expect(await repository.listNotes(), hasLength(6));
        await repository.close();
        expect(await repository.listNotes(), isEmpty);
        expect(await repository.listLabels(), isEmpty);
        expect(await PreviewNoteRepository().listNotes(), hasLength(6));
      },
    );
  });
}

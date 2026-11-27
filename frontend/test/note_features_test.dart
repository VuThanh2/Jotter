import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/data/note_features_api.dart';
import 'package:jotter/data/note_repository.dart';

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
ApiNoteRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) => ApiNoteRepository.fromSession(
  baseUrl: 'http://localhost:5080',
  session: {
    'accessToken': 'test-token',
    'user': {
      'userId': 'owner',
      'email': 'owner@example.com',
      'displayName': 'Owner',
      'isActivated': true,
    },
  },
  client: MockClient(handler),
);

void main() {
  test('sharing sends an individual permission for each recipient', () async {
    final repository = _repository((request) async {
      expect(jsonDecode(request.body), {
        'recipients': [
          {'email': 'one@example.com', 'permission': 'ReadOnly'},
          {'email': 'two@example.com', 'permission': 'Edit'},
        ],
      });
      return _json({
        'created': [{}, {}],
        'rejected': [],
      }, 201);
    });
    final result = await repository.inviteRecipients('note-1', [
      (email: 'one@example.com', permission: 'ReadOnly'),
      (email: 'two@example.com', permission: 'Edit'),
    ]);
    expect(result.created, 2);
    expect(result.rejected, isEmpty);
  });

  test(
    'SSE survives arbitrary chunks and replaces deltas with final summary',
    () async {
      final events = await decodeSummaryEvents(
        Stream.fromIterable([
          ': keepalive\r',
          '\nevent: delta\r\ndata: {"delta":"A café "}\r\n\r',
          '\nevent: delta\ndata: {"delta":"idea."}\n\nevent: completed\ndata: {"summaryText":"A café idea.",',
          '\ndata: "generatedAt":"2026-10-28T08:00:00Z"}\n\n',
        ]),
      ).toList();
      expect(events.map((event) => event.kind), [
        'delta',
        'delta',
        'completed',
      ]);
      expect(events[0].text, 'A café ');
      expect(events.last.text, 'A café idea.');
      expect(events.last.generatedAt, DateTime.utc(2026, 10, 28, 8));
    },
  );

  test(
    'SSE failure is surfaced and an incomplete stream never looks saved',
    () async {
      final failed = await decodeSummaryEvents(
        Stream.value(
          'event: failed\ndata: {"code":"LlmUnavailable","message":"Try later."}\n\n',
        ),
      ).toList();
      expect(failed.single.kind, 'failed');
      expect(failed.single.message, 'Try later.');
      await expectLater(
        decodeSummaryEvents(
          Stream.value('event: delta\ndata: {"delta":"partial"}\n\n'),
        ).toList(),
        throwsA(isA<RepositoryException>()),
      );
    },
  );

  test('cancelling summary decoding cancels its source subscription', () async {
    var cancelled = false;
    final source = StreamController<String>(
      onCancel: () {
        cancelled = true;
      },
    );
    final received = Completer<void>();
    final subscription = decodeSummaryEvents(source.stream).listen((_) {
      if (!received.isCompleted) received.complete();
    });
    source.add('event: delta\ndata: {"delta":"hello"}\n\n');
    await received.future;
    await subscription.cancel();
    expect(cancelled, isTrue);
    await source.close();
  });

  test(
    'sharing sends permissions and retains partial rejection details',
    () async {
      final repository = _repository((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/notes/note-1/shares');
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(request.headers['idempotency-key'], isNotEmpty);
        expect(jsonDecode(request.body), {
          'recipients': [
            {'email': 'friend@example.com', 'permission': 'Edit'},
            {'email': 'unknown@example.com', 'permission': 'Edit'},
          ],
        });
        return _json({
          'created': [
            {'shareId': 'share-1'},
          ],
          'rejected': [
            {'email': 'unknown@example.com', 'code': 'RecipientNotRegistered'},
          ],
        }, 201);
      });
      final result = await repository.inviteToNote('note-1', [
        ' friend@example.com ',
        'unknown@example.com',
      ], 'Edit');
      expect(result.created, 1);
      expect(result.rejected.single.email, 'unknown@example.com');
      await expectLater(
        repository.inviteToNote('note-1', ['friend@example.com'], 'Owner'),
        throwsA(isA<RepositoryException>()),
      );
    },
  );

  test(
    'protection uses exact password contracts and never a query string',
    () async {
      final requests = <http.Request>[];
      final repository = _repository((request) async {
        requests.add(request);
        return _json({});
      });
      await repository.enableProtection('note-1', 'safe', 'safe');
      await repository.changeNotePassword(
        'note-1',
        'safe',
        'new password',
        'new password',
      );
      await repository.disableProtection('note-1', 'new password');
      await repository.relockNote('note-1');
      expect(jsonDecode(requests[0].body), {
        'password': 'safe',
        'confirmPassword': 'safe',
      });
      expect(jsonDecode(requests[1].body), {
        'currentPassword': 'safe',
        'newPassword': 'new password',
        'confirmPassword': 'new password',
      });
      expect(jsonDecode(requests[2].body), {'currentPassword': 'new password'});
      expect(requests[3].method, 'DELETE');
      expect(requests[3].url.path, '/api/notes/note-1/unlock');
      expect(requests.every((request) => request.url.query.isEmpty), isTrue);
      await expectLater(
        repository.enableProtection('note-1', 'abc', 'abc'),
        throwsA(isA<RepositoryException>()),
      );
      await expectLater(
        repository.enableProtection('note-1', 'abcd', 'different'),
        throwsA(isA<RepositoryException>()),
      );
      expect(requests, hasLength(4));
    },
  );

  test(
    'attachment upload uses files multipart field and validates unsafe bytes',
    () async {
      final repository = _repository((request) async {
        expect(request.url.path, '/api/notes/note-1/attachments');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        expect(request.body, contains('name="files"; filename="idea.txt"'));
        expect(request.body, contains('A useful thought'));
        return _json({'items': []}, 201);
      });
      await repository.attachFile(
        'note-1',
        Uint8List.fromList(utf8.encode('A useful thought')),
        'idea.txt',
      );
      expect(
        () => validateAttachment(Uint8List(0), 'empty.txt'),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => validateAttachment(
          Uint8List.fromList([0x4d, 0x5a, 1, 2]),
          'unsafe.exe',
        ),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () =>
            validateAttachment(Uint8List(maxAttachmentBytes + 1), 'large.bin'),
        throwsA(isA<RepositoryException>()),
      );
    },
  );

  test('asking notes sends the question and decodes citations', () async {
    final repository = _repository((request) async {
      expect(request.url.path, '/api/ai/ask');
      expect(jsonDecode(request.body), {'question': 'What is next?'});
      return _json({
        'answer': 'Finish the first draft.',
        'hasEnoughContext': true,
        'citations': [
          {
            'noteId': 'note-1',
            'title': 'Project',
            'excerpt': 'Finish the first draft.',
            'score': .9,
          },
        ],
      });
    });
    final answer = await repository.askNotes(' What is next? ');
    expect(answer.citations.single.noteId, 'note-1');
    expect(answer.hasEnoughContext, isTrue);
  });
}

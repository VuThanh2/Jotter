import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/widgets/note_details_dialog.dart';

void main() {
  Future<ValueNotifier<Map<String, dynamic>?>> open(
    WidgetTester tester,
    String tab,
  ) async {
    final updates = ValueNotifier<Map<String, dynamic>?>(null);
    final api = ApiNoteRepository.fromSession(
      baseUrl: 'https://jotter.test',
      session: {
        'accessToken': 'test',
        'user': {
          'userId': 'owner',
          'email': 'owner@jotter.test',
          'displayName': 'Owner',
          'isActivated': true,
        },
      },
      client: MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('/summary')
              ? '{"summaryText":"A private summary","generatedAt":"2026-10-28T00:00:00Z"}'
              : '{"items":[]}',
          200,
        ),
      ),
    );
    addTearDown(api.dispose);
    addTearDown(updates.dispose);
    final now = DateTime(2026, 10, 28);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showNoteDetailsDialog(
                context,
                repository: api,
                note: JotterNote(
                  id: 'note',
                  title: 'A note',
                  content: 'Content',
                  createdAt: now,
                  updatedAt: now,
                ),
                initialTab: tab,
                updates: updates,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return updates;
  }

  testWidgets(
    'new protection removes a rendered summary and requires unlocking',
    (tester) async {
      final updates = await open(tester, 'Summary');
      expect(find.text('A private summary'), findsOneWidget);
      updates.value = {
        'type': 'accessRevoked',
        'noteId': 'note',
        'isProtected': true,
      };
      await tester.pumpAndSettle();
      expect(find.text('A private summary'), findsNothing);
      expect(find.text('Unlock note'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('read-only permission removes attachment write controls', (
    tester,
  ) async {
    final updates = await open(tester, 'Files');
    expect(find.text('Attach a file'), findsOneWidget);
    updates.value = {
      'type': 'permissionChanged',
      'noteId': 'note',
      'permission': 'ReadOnly',
    };
    await tester.pumpAndSettle();
    expect(find.text('Attach a file'), findsNothing);
    expect(
      find.text(
        'You have view-only access. You can preview and download files.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

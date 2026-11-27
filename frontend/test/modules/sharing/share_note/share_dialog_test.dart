import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/modules/sharing/share_note/share_dialog.dart';

import '../../../helpers/fake_api.dart';

final _note = JotterNote(
  id: 'note-1',
  title: 'Offsite plan',
  content: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Map<String, Object> _share(String id, String email, String permission) => {
  'shareId': id,
  'recipientEmail': email,
  'recipientDisplayName': '',
  'permission': permission,
};

void main() {
  testWidgets('each invitee gets the access chosen for them', (tester) async {
    Map<String, dynamic>? sent;
    final api = fakeApi((request) async {
      if (request.method == 'POST') {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse({
          'created': [{}, {}],
          'rejected': [],
        }, 201);
      }
      return jsonResponse({'items': []});
    });
    await openWithApi(
      tester,
      api,
      (context) => showShareDialog(context, _note),
    );

    await tester.enterText(
      find.byKey(const Key('share-emails')),
      'one@example.com, two@example.com',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('invite-permission:two@example.com')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Can edit').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-send')));
    await tester.pumpAndSettle();

    expect(sent, {
      'recipients': [
        {'email': 'one@example.com', 'permission': 'ReadOnly'},
        {'email': 'two@example.com', 'permission': 'Edit'},
      ],
    });
    expect(find.text('Invited 2 people.'), findsOneWidget);
  });

  testWidgets('when nobody is invited every address still gets its reason', (
    tester,
  ) async {
    final api = fakeApi((request) async {
      if (request.method == 'POST') {
        return jsonResponse({
          'code': 'DuplicateShare',
          'rejected': [
            {'email': 'bob@example.com', 'code': 'DuplicateShare'},
            {'email': 'me@example.com', 'code': 'CannotShareWithSelf'},
          ],
        }, 409);
      }
      return jsonResponse({'items': []});
    });
    await openWithApi(
      tester,
      api,
      (context) => showShareDialog(context, _note),
    );

    await tester.enterText(
      find.byKey(const Key('share-emails')),
      'bob@example.com, me@example.com',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share-send')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'bob@example.com: This person already has access.\n'
        'me@example.com: You cannot share a note with yourself.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('share-emails')))
          .controller!
          .text,
      'bob@example.com, me@example.com',
    );
  });

  testWidgets('rejected addresses stay in the field with a reason', (
    tester,
  ) async {
    final api = fakeApi((request) async {
      if (request.method == 'POST') {
        return jsonResponse({
          'created': [{}],
          'rejected': [
            {'email': 'nobody@example.com', 'code': 'RecipientNotRegistered'},
          ],
        }, 201);
      }
      return jsonResponse({'items': []});
    });
    await openWithApi(
      tester,
      api,
      (context) => showShareDialog(context, _note),
    );

    await tester.enterText(
      find.byKey(const Key('share-emails')),
      'friend@example.com, nobody@example.com',
    );
    // Enter sends, just like the button.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('share-emails')))
          .controller!
          .text,
      'nobody@example.com',
    );
    expect(
      find.text('nobody@example.com: No Jotter account uses this email.'),
      findsOneWidget,
    );
    expect(find.text('Invited 1 person.'), findsOneWidget);
  });

  testWidgets('owners can change and remove access', (tester) async {
    final requests = <String>[];
    final api = fakeApi((http.Request request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.method == 'GET') {
        return jsonResponse({
          'items': [_share('s1', 'reader@example.com', 'ReadOnly')],
        });
      }
      return jsonResponse(null, 204);
    });
    await openWithApi(
      tester,
      api,
      (context) => showShareDialog(context, _note),
    );

    await tester.tap(find.text('Can view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Can edit').last);
    await tester.pumpAndSettle();
    expect(find.text('reader@example.com can now edit.'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove access for reader@example.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove access'));
    await tester.pumpAndSettle();

    expect(find.text('Only you can open this note.'), findsOneWidget);
    expect(requests, [
      'GET /api/notes/note-1/shares',
      'PUT /api/notes/note-1/shares/s1',
      'DELETE /api/notes/note-1/shares/s1',
    ]);
  });

  testWidgets('fits a 320px phone and ignores unfinished addresses', (
    tester,
  ) async {
    final api = fakeApi((request) async => jsonResponse({'items': []}));
    await openWithApi(
      tester,
      api,
      (context) => showShareDialog(context, _note),
      size: const Size(320, 640),
    );
    await tester.enterText(
      find.byKey(const Key('share-emails')),
      'a.very.long.recipient.name@example.com, half@exa',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey(
          'invite-permission:a.very.long.recipient.name@example.com',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('invite-permission:half@exa')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

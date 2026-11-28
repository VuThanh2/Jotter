import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/modules/protection/manage_protection/protection_panel.dart';

import '../../../helpers/fake_api.dart';

JotterNote _note({bool protected = false}) => JotterNote(
  id: 'note-1',
  title: 'Diary',
  content: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  isProtected: protected,
);

Finder _field(String name) => find.descendant(
  of: find.byKey(ValueKey('note-password-$name')),
  matching: find.byType(EditableText),
);

void main() {
  testWidgets('adding a password asks twice and Enter submits', (tester) async {
    Map<String, dynamic>? body;
    var changed = false;
    final api = fakeApi((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return jsonResponse({'noteId': 'note-1', 'isProtected': true});
    });
    await openWithApi(tester, api, (context) async {
      changed = await showProtectionPanel(context, _note());
    });

    await tester.enterText(_field('newPassword'), 'pass1');
    await tester.enterText(_field('confirmation'), 'pass2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(body, isNull);

    await tester.enterText(_field('confirmation'), 'pass1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(body, {'password': 'pass1', 'confirmPassword': 'pass1'});
    expect(changed, isTrue);
    expect(find.text('Add a password'), findsNothing);
  });

  testWidgets('a wrong password keeps the dialog open with the reason', (
    tester,
  ) async {
    var changed = false;
    var attempts = 0;
    final api = fakeApi((request) async {
      attempts++;
      return attempts == 1
          ? jsonResponse({'code': 'InvalidNotePassword'}, 400)
          : jsonResponse(null, 204);
    });
    await openWithApi(tester, api, (context) async {
      changed = await showProtectionPanel(context, _note(protected: true));
    });
    await tester.tap(find.text('Remove password'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('current'), 'wrong');
    await tester.tap(find.byKey(const Key('note-password-submit')));
    await tester.pumpAndSettle();
    expect(find.text('The note password is not correct.'), findsOneWidget);

    await tester.enterText(_field('current'), 'right');
    await tester.tap(find.byKey(const Key('note-password-submit')));
    await tester.pumpAndSettle();
    expect(changed, isTrue);
  });

  testWidgets('cancelling leaves no stale error behind', (tester) async {
    final api = fakeApi(
      (request) async => jsonResponse({'code': 'InvalidNotePassword'}, 400),
    );
    await openWithApi(
      tester,
      api,
      (context) => showProtectionPanel(context, _note(protected: true)),
    );
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('current'), 'wrong');
    await tester.enterText(_field('newPassword'), 'next1');
    await tester.enterText(_field('confirmation'), 'next1');
    await tester.tap(find.byKey(const Key('note-password-submit')));
    await tester.pumpAndSettle();
    expect(find.text('The note password is not correct.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Password protection'), findsOneWidget);
    expect(find.text('The note password is not correct.'), findsNothing);
  });
}

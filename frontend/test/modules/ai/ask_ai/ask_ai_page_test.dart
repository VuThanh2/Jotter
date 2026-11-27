import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/data/api_note_repository.dart';
import 'package:jotter/modules/ai/ask_ai/ask_ai_page.dart';

import '../../../helpers/fake_api.dart';

Future<void> _pump(WidgetTester tester, ApiNoteRepository api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/ask',
    routes: [
      GoRoute(path: '/ask', builder: (_, _) => const AskAiPage()),
      GoRoute(
        path: '/notes/:id',
        builder: (_, state) => Text('Opened ${state.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    RepositoryProvider.value(
      value: api,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an answer lists its sources and a source opens its note', (
    tester,
  ) async {
    final api = fakeApi(
      (request) async => jsonResponse({
        'answer': 'Book the venue first.',
        'hasEnoughContext': true,
        'citations': [
          {
            'noteId': 'note-7',
            'title': 'Offsite plan',
            'excerpt': 'Venue before catering.',
          },
        ],
      }),
    );
    await _pump(tester, api);
    await tester.enterText(
      find.byKey(const Key('ask-notes-question')),
      'What comes first?',
    );
    await tester.tap(find.byKey(const Key('ask-notes-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Book the venue first.'), findsOneWidget);
    // A tap means touch, so the soft keyboard steps aside for the answer.
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
    await tester.ensureVisible(find.text('Offsite plan'));
    await tester.tap(find.text('Offsite plan'));
    await tester.pumpAndSettle();
    expect(find.text('Opened note-7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl+Enter asks and missing context is said plainly', (
    tester,
  ) async {
    var asked = 0;
    final api = fakeApi((request) async {
      asked++;
      return jsonResponse({
        'answer': 'I could not find this in your notes.',
        'hasEnoughContext': false,
        'citations': [],
      });
    });
    await _pump(tester, api);
    await tester.enterText(
      find.byKey(const Key('ask-notes-question')),
      'Who won the 1998 final?',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(asked, 1);
    expect(find.textContaining('don’t say enough'), findsOneWidget);
    expect(find.text('I could not find this in your notes.'), findsNothing);
    // Focus stays on the question, so Tab moves on to Ask and the sources.
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('ask-notes-question')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.focusNode.hasFocus, isTrue);
  });
}

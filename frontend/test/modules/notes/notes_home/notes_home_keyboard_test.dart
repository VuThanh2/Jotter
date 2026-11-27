import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jotter/models/jotter_label.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/models/sync_status.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';
import 'package:jotter/modules/notes/notes_home/notes_home_page.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/modules/profile/preferences/preferences_cubit.dart';
import 'package:jotter/modules/profile/preferences/preferences_store.dart';

class _Notes extends Fake implements NoteStore {
  @override
  ValueNotifier<WorkspaceSyncStatus> get syncStatus =>
      ValueNotifier(const WorkspaceSyncStatus());
  @override
  List<JotterNote> get notes => [];
  @override
  Stream<List<JotterNote>> watchNotes() => Stream.value([]);
  @override
  Future<void> refresh() async {}
}

class _Labels extends Fake implements LabelStore {
  @override
  Stream<List<JotterLabel>> watchLabels() => Stream.value([]);
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  String initialLocation = '/notes',
}) async {
  final prefs = PreferencesCubit(PreferencesStore());
  addTearDown(prefs.close);
  // Same shape as the app: tabs in a shell, the editor pushed over it.
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => shell,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/notes', builder: (_, _) => const NotesHomePage()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/notes/:id',
        builder: (_, state) => const Scaffold(
          body: Column(
            children: [Text('Editor open'), TextField(autofocus: true)],
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<NoteStore>.value(value: _Notes()),
        RepositoryProvider<LabelStore>.value(value: _Labels()),
      ],
      child: BlocProvider.value(
        value: prefs,
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Ctrl+K reaches search even after a click on empty space', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    final searchFocus = FocusManager.instance.primaryFocus;
    searchFocus!.unfocus();
    // Clicking empty space used to leave nothing focused inside the page,
    // which silenced its shortcuts.
    await tester.tapAt(const Offset(700, 560));
    await tester.pump();

    await _press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyK,
    );
    expect(FocusManager.instance.primaryFocus, same(searchFocus));
  });

  testWidgets('Alt+N opens a new note', (tester) async {
    await _pump(tester);
    await tester.tapAt(const Offset(700, 560));
    await _press(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyN);
    expect(find.text('Editor open'), findsOneWidget);
  });

  testWidgets('shortcuts work again after closing the editor', (tester) async {
    final router = await _pump(tester);
    await _press(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyN);
    expect(find.text('Editor open'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyN);
    expect(find.text('Editor open'), findsOneWidget);
  });

  testWidgets('shortcuts work after leaving an editor opened by link', (
    tester,
  ) async {
    final router = await _pump(tester, initialLocation: '/notes/abc');
    router.go('/notes');
    await tester.pumpAndSettle();

    await _press(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyN);
    expect(find.text('Editor open'), findsOneWidget);
  });
}

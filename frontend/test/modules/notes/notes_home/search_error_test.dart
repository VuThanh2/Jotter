import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/models/jotter_label.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/models/sync_status.dart';
import 'package:jotter/modules/labels/shared/label_store.dart';
import 'package:jotter/modules/notes/notes_home/notes_home_cubit.dart';
import 'package:jotter/modules/notes/notes_home/notes_home_page.dart';
import 'package:jotter/modules/notes/shared/note_store.dart';
import 'package:jotter/modules/profile/preferences/preferences_cubit.dart';
import 'package:jotter/modules/profile/preferences/preferences_store.dart';

class _Notes extends Fake implements NoteStore {
  final requests = <String, Completer<List<JotterNote>>>{};
  final status = ValueNotifier(const WorkspaceSyncStatus());
  @override
  ValueNotifier<WorkspaceSyncStatus> get syncStatus => status;
  @override
  List<JotterNote> get notes => [];
  @override
  Stream<List<JotterNote>> watchNotes() => Stream.value([]);
  @override
  Future<void> refresh() async {}
  @override
  Future<List<JotterNote>> search(String query) =>
      (requests[query] = Completer<List<JotterNote>>()).future;
}

class _Labels extends Fake implements LabelStore {
  @override
  Stream<List<JotterLabel>> watchLabels() => Stream.value([]);
}

void main() {
  testWidgets('an offline first load shows retry instead of an empty list', (
    tester,
  ) async {
    final notes = _Notes()
      ..status.value = const WorkspaceSyncStatus(isOffline: true);
    final prefs = PreferencesCubit(PreferencesStore());
    addTearDown(prefs.close);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<NoteStore>.value(value: notes),
          RepositoryProvider<LabelStore>.value(value: _Labels()),
        ],
        child: BlocProvider.value(
          value: prefs,
          child: const MaterialApp(home: NotesHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('could not be refreshed while offline'),
      findsOneWidget,
    );
    expect(find.text('Good things start with a note'), findsNothing);
    notes.status.value = const WorkspaceSyncStatus();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Good things start with a note'), findsOneWidget);
  });
  testWidgets('search failure shows an error and retry loads results', (
    tester,
  ) async {
    final notes = _Notes();
    final prefs = PreferencesCubit(PreferencesStore());
    addTearDown(prefs.close);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<NoteStore>.value(value: notes),
          RepositoryProvider<LabelStore>.value(value: _Labels()),
        ],
        child: BlocProvider.value(
          value: prefs,
          child: const MaterialApp(home: NotesHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'orchid');
    await tester.pump(const Duration(milliseconds: 300));
    notes.requests['orchid']!.completeError(
      const RepositoryException('Search unavailable'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search unavailable'), findsOneWidget);
    expect(find.textContaining('Nothing matches'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    final date = DateTime(2026);
    notes.requests['orchid']!.complete([
      JotterNote(
        id: '1',
        title: 'Orchid',
        content: 'flower',
        createdAt: date,
        updatedAt: date,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Orchid'), findsOneWidget);
    expect(find.text('Search unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refining a query keeps the previous results on screen', (
    tester,
  ) async {
    final notes = _Notes();
    final prefs = PreferencesCubit(PreferencesStore());
    addTearDown(prefs.close);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<NoteStore>.value(value: notes),
          RepositoryProvider<LabelStore>.value(value: _Labels()),
        ],
        child: BlocProvider.value(
          value: prefs,
          child: const MaterialApp(home: NotesHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'orc');
    await tester.pump(const Duration(milliseconds: 300));
    final date = DateTime(2026);
    notes.requests['orc']!.complete([
      JotterNote(
        id: '1',
        title: 'Orchid',
        content: 'flower',
        createdAt: date,
        updatedAt: date,
      ),
    ]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'orch');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Orchid'), findsOneWidget);
    expect(find.textContaining('Nothing matches'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    notes.requests['orch']!.complete([]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing matches'), findsOneWidget);
  });

  test('older search cannot replace a newly entered query', () async {
    final notes = _Notes();
    final cubit = NotesHomeCubit(notes, _Labels());
    addTearDown(cubit.close);
    cubit.search('old');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    cubit.search('new');
    final date = DateTime(2026);
    notes.requests['old']!.complete([
      JotterNote(
        id: 'old',
        title: 'Old',
        content: '',
        createdAt: date,
        updatedAt: date,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.query, 'new');
    expect(cubit.state.searchResults, isNull);
  });
}

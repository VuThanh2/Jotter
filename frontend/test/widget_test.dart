import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/data/preview_note_repository.dart';
import 'package:jotter/main.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/widgets/note_card.dart';

void main() {
  Future<PreviewNoteRepository> openWorkspace(
    WidgetTester tester, {
    Size size = const Size(1440, 1600),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = PreviewNoteRepository();
    await tester.pumpWidget(JotterApp(repository: repository));
    await tester.pumpAndSettle();
    return repository;
  }

  Finder searchField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.hintText == 'Search your notes…',
  );

  Future<void> saveDraft(
    WidgetTester tester, {
    required String title,
    required String content,
  }) async {
    await tester.enterText(find.byKey(const Key('note-title')), title);
    await tester.enterText(find.byKey(const Key('note-content')), content);
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'search filters notes and clearing an empty result restores them',
    (tester) async {
      await openWorkspace(tester);
      expect(find.byType(NoteCard), findsNWidgets(6));

      await tester.enterText(searchField(), 'slow Sunday');
      await tester.pumpAndSettle();
      expect(find.byType(NoteCard), findsOneWidget);
      expect(find.text('Notes from a slow Sunday'), findsOneWidget);

      await tester.enterText(searchField(), 'a phrase that is not in any note');
      await tester.pumpAndSettle();
      expect(find.byType(NoteCard), findsNothing);
      expect(find.text('No thoughts found. Yet.'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteCard), findsNWidgets(6));
      expect(find.text('No thoughts found. Yet.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'server search finds content beyond previews and ignores stale responses',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime(2026, 10, 28);
      final earlier = JotterNote(
        id: 'earlier-result',
        title: 'Studio notes',
        content: '${List.filled(25, 'Opening paragraph. ').join()}orchid',
        preview: 'Opening paragraph.',
        createdAt: now,
        updatedAt: now,
      );
      final latest = JotterNote(
        id: 'latest-result',
        title: 'Weekend plans',
        content: '${List.filled(25, 'A few plans. ').join()}seaside',
        preview: 'A few plans.',
        createdAt: now,
        updatedAt: now,
      );
      final repository = _ControlledSearchRepository([earlier, latest]);
      await tester.pumpWidget(JotterApp(repository: repository));
      await tester.pumpAndSettle();

      await tester.enterText(searchField(), 'orchid');
      await tester.pump(const Duration(milliseconds: 299));
      expect(repository.queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.queries, ['orchid']);

      await tester.enterText(searchField(), 'seaside');
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.queries, ['orchid', 'seaside']);
      repository.completeQuery('seaside', [latest]);
      await tester.pumpAndSettle();

      expect(find.text('Weekend plans'), findsOneWidget);
      expect(find.text('Studio notes'), findsNothing);
      final result = tester.widget<NoteCard>(find.byType(NoteCard)).note;
      expect(result.contentLoaded, isFalse);
      expect('${result.title} ${result.preview}', isNot(contains('seaside')));

      repository.completeQuery('orchid', [earlier]);
      await tester.pumpAndSettle();
      expect(find.text('Weekend plans'), findsOneWidget);
      expect(find.text('Studio notes'), findsNothing);
      expect(find.byType(NoteCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'creating and editing a note saves the visible text and content',
    (tester) async {
      final repository = await openWorkspace(tester);
      await tester.tap(find.text('New note').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save-note')))
            .onPressed,
        isNull,
      );

      await saveDraft(
        tester,
        title: 'An idea to keep',
        content: 'Build a small reading nook by the window.',
      );
      expect(find.byKey(const Key('note-title')), findsNothing);
      expect(find.text('An idea to keep'), findsOneWidget);
      final created = (await repository.listNotes()).singleWhere(
        (note) => note.title == 'An idea to keep',
      );
      expect(created.content, 'Build a small reading nook by the window.');
      expect(created.version, 1);

      await tester.tap(find.text('An idea to keep'));
      await tester.pumpAndSettle();
      await saveDraft(
        tester,
        title: 'A reading nook',
        content: 'Add a comfortable chair and a warm lamp.',
      );
      expect(find.text('An idea to keep'), findsNothing);
      expect(find.text('A reading nook'), findsOneWidget);
      final updated = await repository.getNote(created.id);
      expect(updated.content, 'Add a comfortable chair and a warm lamp.');
      expect(updated.version, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new labels can contain a newly created note', (tester) async {
    final repository = await openWorkspace(tester);
    await tester.tap(find.byTooltip('Create label'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Reading');
    await tester.tap(find.widgetWithText(FilledButton, 'Create label'));
    await tester.pumpAndSettle();

    expect(find.text('Reading'), findsWidgets);
    expect(find.text('Good things start with a note.'), findsOneWidget);
    final label = (await repository.listLabels()).singleWhere(
      (label) => label.name == 'Reading',
    );

    await tester.tap(find.text('New note').first);
    await tester.pumpAndSettle();
    await saveDraft(
      tester,
      title: 'The next chapter',
      content: 'Make time for twenty pages before bed.',
    );
    expect(find.text('The next chapter'), findsOneWidget);
    final saved = (await repository.listNotes()).singleWhere(
      (note) => note.title == 'The next chapter',
    );
    expect(saved.labelIds, contains(label.id));
    expect(find.byType(NoteCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar sections filter pinned and shared notes', (
    tester,
  ) async {
    await openWorkspace(tester);
    await tester.tap(find.text('Pinned notes').first);
    await tester.pumpAndSettle();
    final pinned = tester.widgetList<NoteCard>(find.byType(NoteCard));
    expect(pinned, hasLength(2));
    expect(pinned.every((card) => card.note.isPinned), isTrue);
    expect(find.text('Notes from a slow Sunday'), findsNothing);

    await tester.tap(find.text('Shared with me').first);
    await tester.pumpAndSettle();
    expect(find.byType(NoteCard), findsNothing);
    expect(find.text('A space for shared ideas.'), findsOneWidget);

    await tester.tap(find.text('All notes').first);
    await tester.pumpAndSettle();
    expect(find.byType(NoteCard), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unpinning a note removes it from the pinned section', (
    tester,
  ) async {
    final repository = await openWorkspace(tester);
    await tester.tap(find.text('Pinned notes').first);
    await tester.pumpAndSettle();
    final card = find.byWidgetPredicate(
      (widget) =>
          widget is NoteCard &&
          widget.note.title == 'A little room for big ideas',
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byTooltip('Note actions')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpin note'));
    await tester.pumpAndSettle();
    expect(find.text('A little room for big ideas'), findsNothing);
    expect(find.byType(NoteCard), findsOneWidget);
    expect(
      (await repository.listNotes())
          .singleWhere((note) => note.title == 'A little room for big ideas')
          .isPinned,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px layout supports the drawer and both note views', (
    tester,
  ) async {
    await openWorkspace(tester, size: const Size(320, 900));
    expect(find.byTooltip('Open navigation'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    expect(find.text('YOUR LABELS'), findsOneWidget);
    await tester.tap(find.text('Pinned notes').first);
    await tester.pumpAndSettle();
    expect(
      tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
      isFalse,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('List view'));
    await tester.pumpAndSettle();
    var cards = tester.widgetList<NoteCard>(find.byType(NoteCard));
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.listMode), isTrue);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Grid view'));
    await tester.pumpAndSettle();
    cards = tester.widgetList<NoteCard>(find.byType(NoteCard));
    expect(cards, isNotEmpty);
    expect(cards.every((card) => !card.listMode), isTrue);
    expect(tester.takeException(), isNull);
  });
}

/// Provides server-style note projections while tests control response order.
class _ControlledSearchRepository extends PreviewNoteRepository {
  _ControlledSearchRepository(this.initialNotes);

  final List<JotterNote> initialNotes;
  final List<String> queries = [];
  final Map<String, Completer<List<JotterNote>>> _pending = {};

  @override
  bool get isPreview => false;

  @override
  Future<List<JotterNote>> listNotes({String? query}) {
    if (query == null || query.isEmpty) {
      return Future.value(initialNotes.map(_projection).toList());
    }
    queries.add(query);
    final response = Completer<List<JotterNote>>();
    _pending[query] = response;
    return response.future;
  }

  void completeQuery(String query, List<JotterNote> notes) {
    _pending.remove(query)!.complete(notes.map(_projection).toList());
  }

  JotterNote _projection(JotterNote note) =>
      note.copyWith(content: '', contentLoaded: false);
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/data/preview_note_repository.dart';
import 'package:jotter/main.dart';
import 'package:jotter/models/jotter_preferences.dart';
import 'package:jotter/screens/workspace_screen.dart';
import 'package:jotter/theme.dart';
import 'package:jotter/widgets/note_card.dart';

void main() {
  Future<PreviewNoteRepository> openWorkspace(
    WidgetTester tester, {
    JotterPreferences preferences = const JotterPreferences(),
    bool systemDark = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.platformDispatcher.platformBrightnessTestValue = systemDark
        ? Brightness.dark
        : Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final repository = PreviewNoteRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: jotterTheme,
        darkTheme: jotterDarkTheme,
        themeMode: ThemeMode.system,
        home: WorkspaceScreen(repository: repository, preferences: preferences),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets(
    'renaming and deleting a label updates notes without deleting their content',
    (tester) async {
      final repository = await openWorkspace(tester);
      final originalNotes = await repository.listNotes();
      final originalContent = {
        for (final note in originalNotes) note.id: note.content,
      };
      final work = (await repository.listLabels()).singleWhere(
        (label) => label.name == 'Work',
      );
      final linkedIds = originalNotes
          .where((note) => note.labelIds.contains(work.id))
          .map((note) => note.id)
          .toSet();
      expect(linkedIds, isNotEmpty);

      await tester.tap(find.text('Manage labels'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rename Work'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Projects');
      await tester.tap(find.widgetWithText(FilledButton, 'Rename label'));
      await tester.pumpAndSettle();
      expect(
        (await repository.listLabels())
            .singleWhere((label) => label.id == work.id)
            .name,
        'Projects',
      );
      expect(find.text('Projects'), findsWidgets);
      expect(
        (await repository.listNotes())
            .where((note) => note.labelIds.contains(work.id))
            .map((note) => note.id)
            .toSet(),
        linkedIds,
      );

      await tester.tap(find.text('Manage labels'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete Projects'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Projects?'), findsOneWidget);
      expect(find.textContaining('The notes are kept.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete label'));
      await tester.pumpAndSettle();
      final remaining = await repository.listNotes();
      expect(remaining, hasLength(originalNotes.length));
      expect({
        for (final note in remaining) note.id: note.content,
      }, originalContent);
      expect(
        remaining.every((note) => !note.labelIds.contains(work.id)),
        isTrue,
      );
      expect(
        (await repository.listLabels()).any((label) => label.id == work.id),
        isFalse,
      );
      expect(find.text('Projects'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview exposes note tools and explains the account requirement',
    (tester) async {
      await openWorkspace(tester);
      const actions = [
        'Files',
        'Share & permissions',
        'Note protection',
        'AI summary',
      ];
      for (final action in actions) {
        final menu = find.descendant(
          of: find.byType(NoteCard).first,
          matching: find.byTooltip('Note actions'),
        );
        await tester.tap(menu);
        await tester.pumpAndSettle();
        for (final name in actions) {
          expect(find.text(name), findsOneWidget);
        }
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Sign in to use files, sharing, protection, and AI with your saved notes.',
          ),
          findsOneWidget,
        );
        final context = tester.element(find.byType(WorkspaceScreen));
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved layout, note color and editor font preferences affect the actual widgets',
    (tester) async {
      await openWorkspace(
        tester,
        preferences: const JotterPreferences(
          noteFontSize: 24,
          defaultNoteColor: '#FFEECC',
          listViewMode: 'List',
        ),
      );
      final cards = tester.widgetList<NoteCard>(find.byType(NoteCard));
      expect(cards, isNotEmpty);
      expect(cards.every((card) => card.listMode), isTrue);
      expect(
        cards.every((card) => card.defaultColor == const Color(0xFFFFEECC)),
        isTrue,
      );
      final cardSurface = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(NoteCard).first,
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (cardSurface.decoration as BoxDecoration).color,
        const Color(0xFFFFEECC),
      );

      await tester.tap(find.text('A little room for big ideas'));
      await tester.pumpAndSettle();
      final content = tester.widget<TextField>(
        find.byKey(const Key('note-content')),
      );
      expect(content.style!.fontSize, 24);
      await tester.tap(find.byTooltip('Close note'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system dark mode selects a readable dark workspace and card palette',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(JotterApp(repository: PreviewNoteRepository()));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(WorkspaceScreen));
      expect(Theme.of(context).brightness, Brightness.dark);
      final colors = context.jotterColors;
      expect(colors.dark, isTrue);
      final contrast =
          (math.max(
                colors.ink.computeLuminance(),
                colors.paper.computeLuminance(),
              ) +
              .05) /
          (math.min(
                colors.ink.computeLuminance(),
                colors.paper.computeLuminance(),
              ) +
              .05);
      expect(contrast, greaterThan(7));
      final cardSurface = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(NoteCard).first,
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        (cardSurface.decoration as BoxDecoration).color!.computeLuminance(),
        lessThan(.15),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

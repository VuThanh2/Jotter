import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/data/note_repository.dart';
import 'package:jotter/models/jotter_label.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/theme.dart';
import 'package:jotter/widgets/note_editor.dart';

JotterNote _note({bool canEdit = true}) => JotterNote(
  id: 'note-1',
  title: 'A thought to keep',
  content: 'The original thought.',
  version: 4,
  createdAt: DateTime(2026, 10, 20),
  updatedAt: DateTime(2026, 10, 27),
  canEdit: canEdit,
  isOwned: canEdit,
  isShared: !canEdit,
  labelIds: const ['personal'],
);

Future<void> _openEditor(
  WidgetTester tester, {
  JotterNote? note,
  required Future<JotterNote> Function(JotterNote) onSave,
  Future<JotterNote> Function(JotterNote)? onSaveCopy,
  Future<void> Function(JotterNote)? onCompare,
  ValueListenable<Map<String, dynamic>?>? updates,
  double noteFontSize = 16,
  ThemeData? theme,
  ValueChanged<JotterNote?>? onClosed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await showNoteEditor(
                context,
                note: note ?? _note(),
                labels: const [JotterLabel(id: 'personal', name: 'Personal')],
                onSave: onSave,
                onSaveCopy: onSaveCopy,
                onCompare: onCompare,
                updates: updates,
                noteFontSize: noteFontSize,
              );
              onClosed?.call(result);
            },
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

String _fieldValue(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  testWidgets('saves the entered content with the original note identity', (
    tester,
  ) async {
    JotterNote? submitted;
    JotterNote? result;
    await _openEditor(
      tester,
      onSave: (note) async {
        submitted = note;
        return note.copyWith(version: 5);
      },
      onClosed: (note) => result = note,
    );

    await tester.enterText(find.byKey(const Key('note-title')), 'A new title');
    await tester.enterText(
      find.byKey(const Key('note-content')),
      'A thought worth saving.',
    );
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();

    expect(submitted?.id, 'note-1');
    expect(submitted?.version, 4);
    expect(submitted?.title, 'A new title');
    expect(submitted?.content, 'A thought worth saving.');
    expect(submitted?.labelIds, ['personal']);
    expect(result?.version, 5);
    expect(find.byKey(const Key('note-content')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the draft and allows another save after a failure', (
    tester,
  ) async {
    var attempts = 0;
    await _openEditor(
      tester,
      onSave: (note) async {
        attempts++;
        if (attempts == 1) {
          throw const RepositoryException('Connection unavailable. Try again.');
        }
        return note.copyWith(version: 5);
      },
    );
    await tester.enterText(
      find.byKey(const Key('note-title')),
      'Keep my draft',
    );
    await tester.enterText(
      find.byKey(const Key('note-content')),
      'This should survive a connection failure.',
    );
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();

    expect(find.text('Connection unavailable. Try again.'), findsOneWidget);
    expect(_fieldValue(tester, 'note-title'), 'Keep my draft');
    expect(
      _fieldValue(tester, 'note-content'),
      'This should survive a connection failure.',
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('save-note'))).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byKey(const Key('note-content')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared read-only notes cannot be edited or saved', (
    tester,
  ) async {
    var saves = 0;
    await _openEditor(
      tester,
      note: _note(canEdit: false),
      onSave: (note) async {
        saves++;
        return note;
      },
    );

    expect(find.text('Read only'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('note-title'))).readOnly,
      isTrue,
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('note-content'))).readOnly,
      isTrue,
    );
    expect(find.byKey(const Key('save-note')), findsNothing);
    expect(find.byTooltip('Insert bullet'), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(saves, 0);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-content')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed save can preserve the complete draft as a copy', (
    tester,
  ) async {
    JotterNote? copiedDraft;
    JotterNote? result;
    await _openEditor(
      tester,
      onSave: (_) async => throw const RepositoryException(
        'This note changed on another device.',
        code: 'VersionConflict',
      ),
      onSaveCopy: (draft) async {
        copiedDraft = draft;
        return draft.copyWith(id: 'copy-1', version: 1);
      },
      onClosed: (note) => result = note,
    );

    expect(find.text('Save a copy'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('note-title')),
      'The title I want to keep',
    );
    await tester.enterText(
      find.byKey(const Key('note-content')),
      'Every line of my draft.\nIncluding this one.',
    );
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();

    expect(find.text('This note changed on another device.'), findsOneWidget);
    expect(find.text('Save a copy'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-note-copy')));
    await tester.pumpAndSettle();

    expect(copiedDraft?.id, 'note-1');
    expect(copiedDraft?.version, 4);
    expect(copiedDraft?.title, 'The title I want to keep');
    expect(
      copiedDraft?.content,
      'Every line of my draft.\nIncluding this one.',
    );
    expect(copiedDraft?.labelIds, ['personal']);
    expect(result?.id, 'copy-1');
    expect(result?.version, 1);
    expect(find.byKey(const Key('note-content')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirms unsaved changes and keeps them until discarded', (
    tester,
  ) async {
    var saves = 0;
    var closed = false;
    await _openEditor(
      tester,
      onSave: (note) async {
        saves++;
        return note;
      },
      onClosed: (_) => closed = true,
    );
    await tester.enterText(
      find.byKey(const Key('note-title')),
      'An unsaved idea',
    );
    await tester.tap(find.byTooltip('Close note'));
    await tester.pumpAndSettle();

    expect(find.text('Keep your changes?'), findsOneWidget);
    expect(closed, isFalse);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(_fieldValue(tester, 'note-title'), 'An unsaved idea');

    await tester.tap(find.byTooltip('Close note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(saves, 0);
    expect(find.byKey(const Key('note-title')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back also guards a dirty draft', (tester) async {
    await _openEditor(tester, onSave: (note) async => note);
    await tester.enterText(
      find.byKey(const Key('note-title')),
      'Still drafting',
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Keep your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(_fieldValue(tester, 'note-title'), 'Still drafting');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a completed save does not update a disposed editor', (
    tester,
  ) async {
    final pending = Completer<JotterNote>();
    await _openEditor(tester, onSave: (_) => pending.future);
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pump();

    expect(find.text('Saving…'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Close note',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Keep your changes?'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(_note().copyWith(version: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a narrow phone and inserts a real checklist item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openEditor(tester, onSave: (note) async => note);

    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Insert checklist item'));
    await tester.pumpAndSettle();
    expect(_fieldValue(tester, 'note-content'), 'The original thought.\n☐ ');
    expect(tester.takeException(), isNull);
  });

  testWidgets('copy recovery controls fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    JotterNote? copied;
    await _openEditor(
      tester,
      onSave: (_) async => throw const RepositoryException(
        'The note changed on another device. Your draft is still here. '
        'Save a copy to keep these changes.',
      ),
      onSaveCopy: (note) async => note.copyWith(id: 'phone-copy'),
      onClosed: (note) => copied = note,
    );

    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();
    expect(find.text('Save a copy'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('save-note-copy')));
    await tester.pumpAndSettle();
    expect(copied?.id, 'phone-copy');
    expect(copied?.content, 'The original thought.');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'live permission loss preserves the draft and only allows a copy',
    (tester) async {
      final updates = ValueNotifier<Map<String, dynamic>?>(null);
      addTearDown(updates.dispose);
      var originalSaves = 0;
      JotterNote? copied;
      await _openEditor(
        tester,
        updates: updates,
        onSave: (note) async {
          originalSaves++;
          return note;
        },
        onSaveCopy: (note) async {
          copied = note;
          return note.copyWith(id: 'saved-copy');
        },
      );
      await tester.enterText(
        find.byKey(const Key('note-title')),
        'An idea worth keeping',
      );
      await tester.enterText(
        find.byKey(const Key('note-content')),
        'Keep the complete unsaved draft.',
      );
      updates.value = {
        'type': 'permissionChanged',
        'noteId': 'note-1',
        'permission': 'ReadOnly',
      };
      await tester.pumpAndSettle();
      expect(
        _fieldValue(tester, 'note-content'),
        'Keep the complete unsaved draft.',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('note-content')))
            .readOnly,
        isTrue,
      );
      expect(find.byKey(const Key('save-note')), findsNothing);
      expect(find.byKey(const Key('copy-draft')), findsOneWidget);
      await tester.tap(find.byKey(const Key('save-note-copy')));
      await tester.pumpAndSettle();
      expect(originalSaves, 0);
      expect(copied?.title, 'An idea worth keeping');
      expect(copied?.content, 'Keep the complete unsaved draft.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live saved-version comparison receives the current unmodified draft',
    (tester) async {
      final updates = ValueNotifier<Map<String, dynamic>?>(null);
      addTearDown(updates.dispose);
      JotterNote? compared;
      await _openEditor(
        tester,
        updates: updates,
        onSave: (note) async => note,
        onCompare: (note) async {
          compared = note;
        },
      );
      await tester.enterText(
        find.byKey(const Key('note-content')),
        'This is my local draft, not the server version.',
      );
      updates.value = {
        'type': 'noteChanged',
        'noteId': 'unrelated-note',
        'version': 9,
      };
      await tester.pump();
      expect(find.byKey(const Key('compare-note-version')), findsNothing);
      updates.value = {
        'type': 'presence',
        'noteId': 'note-1',
        'users': [
          {'userId': 'friend', 'displayName': 'Alex'},
        ],
      };
      await tester.pump();
      expect(find.text('Here now: Alex'), findsOneWidget);
      updates.value = {'type': 'noteChanged', 'noteId': 'note-1', 'version': 5};
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('compare-note-version')));
      await tester.pumpAndSettle();
      expect(compared?.id, 'note-1');
      expect(compared?.version, 4);
      expect(
        compared?.content,
        'This is my local draft, not the server version.',
      );
      expect(_fieldValue(tester, 'note-content'), compared?.content);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a save conflict exposes comparison without discarding text', (
    tester,
  ) async {
    JotterNote? compared;
    await _openEditor(
      tester,
      onSave: (_) async => throw const RepositoryException(
        'The saved note changed.',
        code: 'VersionConflict',
      ),
      onCompare: (note) async {
        compared = note;
      },
    );
    await tester.enterText(
      find.byKey(const Key('note-content')),
      'The draft I still need.',
    );
    await tester.tap(find.byKey(const Key('save-note')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compare-note-version')));
    await tester.pumpAndSettle();
    expect(compared?.content, 'The draft I still need.');
    expect(_fieldValue(tester, 'note-content'), 'The draft I still need.');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'protected access invalidation removes readable content and copy controls',
    (tester) async {
      final updates = ValueNotifier<Map<String, dynamic>?>(null);
      addTearDown(updates.dispose);
      await _openEditor(
        tester,
        updates: updates,
        note: _note().copyWith(isProtected: true),
        onSave: (note) async => note,
        onSaveCopy: (note) async => note,
      );
      updates.value = {
        'type': 'accessRevoked',
        'noteId': 'note-1',
        'isProtected': true,
      };
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note-content')), findsNothing);
      expect(find.byKey(const Key('note-title')), findsNothing);
      expect(find.byKey(const Key('save-note-copy')), findsNothing);
      expect(find.byKey(const Key('copy-draft')), findsNothing);
      expect(find.text('Content hidden'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved font size and the dark palette are applied to the editor',
    (tester) async {
      await _openEditor(
        tester,
        noteFontSize: 24,
        theme: jotterDarkTheme,
        onSave: (note) async => note,
      );
      final content = tester.widget<TextField>(
        find.byKey(const Key('note-content')),
      );
      expect(content.style?.fontSize, 24);
      expect(content.style?.color, const Color(0xFFE5E7DF));
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
        const Color(0xFF1B201D),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

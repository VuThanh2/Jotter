import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/models/jotter_note.dart';
import 'package:jotter/shared/widgets/note_card.dart';

void main() {
  testWidgets('protected card hides content and displays all indicators', (
    tester,
  ) async {
    final note = JotterNote(
      id: '1',
      title: 'Private',
      content: 'secret text',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      isPinned: true,
      isShared: true,
      isProtected: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: NoteCard(note: note, onOpen: () {}),
          ),
        ),
      ),
    );
    expect(find.text('secret text'), findsNothing);
    expect(find.byTooltip('Pinned'), findsOneWidget);
    expect(find.byTooltip('Shared with others'), findsOneWidget);
    expect(find.byTooltip('Password protected'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/modules/notes/note_editor/note_editor_state.dart';
import 'package:jotter/modules/notes/note_editor/save_status_indicator.dart';

void main() {
  testWidgets('failed save shows the error and allows retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SaveStatusIndicator(
            status: SaveStatus.failed,
            error: 'Network unavailable',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.text('Not saved'), findsOneWidget);
    expect(find.byTooltip('Network unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/shared/widgets/page_shortcuts.dart';

Future<List<String>> _pump(
  WidgetTester tester, {
  bool autofocusField = false,
  bool autofocusPage = false,
  bool fieldLater = false,
}) async {
  final fired = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: PageShortcuts(
        autofocus: autofocusPage,
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              fired.add('escape'),
        },
        child: Scaffold(
          body: Column(
            children: [
              if (fieldLater)
                FutureBuilder(
                  future: Future<void>.delayed(const Duration(seconds: 1)),
                  builder: (_, snapshot) =>
                      snapshot.connectionState == ConnectionState.done
                      ? TextField(
                          key: const Key('field'),
                          autofocus: autofocusField,
                        )
                      : const SizedBox(),
                )
              else
                TextField(key: const Key('field'), autofocus: autofocusField),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fired;
}

void main() {
  testWidgets('a field that appears later still gets its autofocus', (
    tester,
  ) async {
    await _pump(tester, autofocusField: true, fieldLater: true);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('with autofocus, shortcuts work before anything is focused', (
    tester,
  ) async {
    final fired = await _pump(tester, autofocusPage: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(fired, ['escape']);
  });

  testWidgets('shortcuts still work after leaving a text field', (
    tester,
  ) async {
    final fired = await _pump(tester);
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(fired, ['escape']);
  });

  testWidgets('shortcuts work again after returning from another page', (
    tester,
  ) async {
    final fired = <String>[];
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: PageShortcuts(
          autofocus: true,
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                fired.add('escape'),
          },
          child: const Scaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: TextField(autofocus: true)),
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(fired, ['escape']);
  });
}

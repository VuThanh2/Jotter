import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/widgets/account_dialog.dart';

void main() {
  Future<void> openSignIn(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAccountDialog(context),
              child: const Text('Open sign in'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sign in'));
    await tester.pumpAndSettle();
  }

  testWidgets('sign-in validates empty credentials without making a request', (
    tester,
  ) async {
    await openSignIn(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(find.text('Your notes, together.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demo credentials are opt-in and password visibility toggles', (
    tester,
  ) async {
    await openSignIn(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      isEmpty,
    );

    await tester.tap(find.text('Use demo credentials'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      'demo@jotter.app',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      'Demo@123',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isTrue,
    );

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Close sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Your notes, together.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection settings use the configured API address', (
    tester,
  ) async {
    await openSignIn(tester);
    await tester.tap(find.text('Connection settings'));
    await tester.pumpAndSettle();
    final address = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(
      address.controller!.text,
      const String.fromEnvironment(
        'API_URL',
        defaultValue: 'http://localhost:5080',
      ),
    );
    expect(find.text('Jotter API address'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

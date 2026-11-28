import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/modules/authentication/login/login_page.dart';

void main() {
  testWidgets('keyboard Tab moves from email to password', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage(passwordReset: true)),
    );
    await tester.pumpAndSettle();
    EditableText field(String key) => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      ),
    );
    expect(field('login-email').focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(field('login-password').focusNode.hasFocus, isTrue);
  });
  testWidgets('login form validates empty credentials', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginPage(passwordReset: true)),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.textContaining('email', findRichText: true), findsWidgets);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
  });
}

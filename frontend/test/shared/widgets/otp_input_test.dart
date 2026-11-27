import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/shared/widgets/otp_input.dart';

void main() {
  testWidgets('six digits complete the code; anything else is dropped', (
    tester,
  ) async {
    final code = TextEditingController();
    addTearDown(code.dispose);
    final completed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpInput(controller: code, onCompleted: completed.add),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '12a34');
    expect(code.text, '1234');
    expect(completed, isEmpty);

    await tester.enterText(find.byType(TextField), '9235261');
    expect(code.text, '923526');
    expect(completed, ['923526']);
  });
}

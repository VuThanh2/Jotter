import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/shared/lib/ai_text.dart';

void main() {
  test('Markdown bullets and bold become plain text', () {
    expect(
      readableAiText('* Tent\n- **Stove**\n  * Lamp'),
      '• Tent\n• Stove\n  • Lamp',
    );
  });

  test('asterisks inside a sentence are kept', () {
    expect(readableAiText('Budget is 2 * 300.'), 'Budget is 2 * 300.');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotter/app/theme/app_theme.dart';

void main() {
  for (final (name, theme) in [
    ('light', jotterTheme),
    ('dark', jotterDarkTheme),
  ]) {
    test('$name buttons draw a ring only while focused', () {
      final styles = [
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
        theme.iconButtonTheme.style!,
      ];
      for (final style in styles) {
        expect(style.side!.resolve({WidgetState.focused})!.width, 2);
        expect(style.side!.resolve({})?.width ?? 1, 1);
      }
    });

    test('$name outlined buttons keep the shared shape', () {
      final style = theme.outlinedButtonTheme.style!;
      expect(
        style.shape!.resolve({}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      );
    });
  }

  test('dark note colours stay distinct', () {
    const palette = JotterPalette(true);
    final tints = {
      for (final color in [
        JotterColors.butter,
        JotterColors.sage,
        JotterColors.peach,
        JotterColors.lavender,
      ])
        palette.tint(color),
    };
    expect(tints, hasLength(4));
    for (final a in tints) {
      for (final b in tints.where((b) => b != a)) {
        final hueGap = (HSLColor.fromColor(a).hue - HSLColor.fromColor(b).hue)
            .abs();
        expect(hueGap, greaterThan(20));
      }
    }
  });
}

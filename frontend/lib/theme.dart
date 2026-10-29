import 'package:flutter/material.dart';

abstract final class JotterColors {
  static const paper = Color(0xFFFAF9F6);
  static const sidebar = Color(0xFFF1F0EB);
  static const ink = Color(0xFF292B28);
  static const muted = Color(0xFF777A72);
  static const accent = Color(0xFFB75032);
  static const line = Color(0xFFE5E5DE);
  static const peach = Color(0xFFF6E7DF);
  static const sage = Color(0xFFEAF0E6);
  static const lavender = Color(0xFFEEEAF3);
  static const butter = Color(0xFFF4EEDC);
}

final jotterTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: JotterColors.paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: JotterColors.accent,
    primary: JotterColors.accent,
    surface: JotterColors.paper,
    onSurface: JotterColors.ink,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 27,
      fontWeight: FontWeight.w600,
      letterSpacing: -.7,
    ),
    titleLarge: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w600,
      letterSpacing: -.4,
    ),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 15, height: 1.6),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, height: 1.5, color: JotterColors.muted),
    labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: .3,
    ),
  ).apply(bodyColor: JotterColors.ink, displayColor: JotterColors.ink),
  dividerColor: JotterColors.line,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: JotterColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: JotterColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: JotterColors.accent, width: 1.5),
    ),
    hintStyle: const TextStyle(color: JotterColors.muted, fontSize: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(44, 46),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: JotterColors.ink,
      side: const BorderSide(color: JotterColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      minimumSize: const Size(44, 44),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: JotterColors.ink,
      borderRadius: BorderRadius.circular(6),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: JotterColors.ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: JotterColors.paper,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
);

final jotterDarkTheme = jotterTheme.copyWith(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF1B201D),
  colorScheme: ColorScheme.fromSeed(
    seedColor: JotterColors.accent,
    brightness: Brightness.dark,
  ).copyWith(surface: const Color(0xFF1B201D)),
  textTheme: jotterTheme.textTheme.apply(
    bodyColor: const Color(0xFFE5E7DF),
    displayColor: const Color(0xFFE5E7DF),
  ),
  dividerColor: const Color(0xFF3D453E),
  inputDecorationTheme: jotterTheme.inputDecorationTheme.copyWith(
    fillColor: const Color(0xFF262D27),
    hintStyle: const TextStyle(color: Color(0xFFAEB5AA)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF3D453E)),
    ),
  ),
  dialogTheme: jotterTheme.dialogTheme.copyWith(
    backgroundColor: const Color(0xFF222923),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFE5E7DF),
      side: const BorderSide(color: Color(0xFF65705F)),
    ),
  ),
);

extension JotterPaletteContext on BuildContext {
  JotterPalette get jotterColors =>
      JotterPalette(Theme.of(this).brightness == Brightness.dark);
}

class JotterPalette {
  const JotterPalette(this.dark);
  final bool dark;
  Color get paper => dark ? const Color(0xFF1B201D) : JotterColors.paper;
  Color get sidebar => dark ? const Color(0xFF242B25) : JotterColors.sidebar;
  Color get ink => dark ? const Color(0xFFE5E7DF) : JotterColors.ink;
  Color get muted => dark ? const Color(0xFFB0B7AB) : JotterColors.muted;
  Color get line => dark ? const Color(0xFF3D453E) : JotterColors.line;
  Color get selected =>
      dark ? const Color(0xFF323B33) : const Color(0xFFE7E5DC);
  Color get panel => dark ? const Color(0xFF2B332C) : const Color(0xFFE8E9E0);
  Color tint(Color color) => dark ? Color.lerp(color, paper, .85)! : color;
}

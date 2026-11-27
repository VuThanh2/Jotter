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
  // Ink wells (navigation, menus, cards) show keyboard focus with this.
  focusColor: JotterColors.ink.withValues(alpha: .16),
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
  cardTheme: _cards(fill: Colors.white, line: JotterColors.line),
  filledButtonTheme: _filledButtons(JotterColors.ink),
  outlinedButtonTheme: _outlinedButtons(
    ink: JotterColors.ink,
    line: JotterColors.line,
  ),
  textButtonTheme: _textButtons(JotterColors.ink),
  iconButtonTheme: _iconButtons(JotterColors.ink),
  segmentedButtonTheme: _segmentedButtons(JotterColors.ink),
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
    bodyColor: _darkInk,
    displayColor: _darkInk,
  ),
  dividerColor: const Color(0xFF3D453E),
  focusColor: _darkInk.withValues(alpha: .2),
  // copyWith would keep the light canvas behind dropdown menus.
  canvasColor: const Color(0xFF222923),
  cardColor: const Color(0xFF242B25),
  popupMenuTheme: const PopupMenuThemeData(color: Color(0xFF2B332C)),
  // Inherited, the light theme's dark snackbar showed dark text on dark.
  snackBarTheme: jotterTheme.snackBarTheme.copyWith(
    backgroundColor: _darkInk,
    contentTextStyle: const TextStyle(color: JotterColors.ink),
    actionTextColor: JotterColors.accent,
  ),
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
  cardTheme: _cards(
    fill: const Color(0xFF242B25),
    line: const Color(0xFF3D453E),
  ),
  filledButtonTheme: _filledButtons(_darkInk),
  outlinedButtonTheme: _outlinedButtons(
    ink: _darkInk,
    line: const Color(0xFF65705F),
  ),
  textButtonTheme: _textButtons(_darkInk),
  iconButtonTheme: _iconButtons(_darkInk),
  segmentedButtonTheme: _segmentedButtons(_darkInk),
);

const _darkInk = Color(0xFFE5E7DF);

/// Flat like note cards; Material's default takes a reddish seed tint.
CardThemeData _cards({required Color fill, required Color line}) =>
    CardThemeData(
      color: fill,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: line),
      ),
    );

/// Material's faint focus layer is easy to miss, so keyboard focus also
/// draws a ring in the text colour, visible on accent buttons too.
WidgetStateProperty<BorderSide?> _focusRing(Color ring, [BorderSide? rest]) =>
    WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: ring, width: 2)
          : rest,
    );

FilledButtonThemeData _filledButtons(Color ring) => FilledButtonThemeData(
  style: FilledButton.styleFrom(
    minimumSize: const Size(44, 46),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
  ).copyWith(side: _focusRing(ring)),
);

OutlinedButtonThemeData _outlinedButtons({
  required Color ink,
  required Color line,
}) => OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    foregroundColor: ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    minimumSize: const Size(44, 44),
  ).copyWith(side: _focusRing(ink, BorderSide(color: line))),
);

TextButtonThemeData _textButtons(Color ring) => TextButtonThemeData(
  style: TextButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ).copyWith(side: _focusRing(ring)),
);

IconButtonThemeData _iconButtons(Color ring) =>
    IconButtonThemeData(style: ButtonStyle(side: _focusRing(ring)));

/// Segments share one outline, so focus shows as a stronger fill instead.
SegmentedButtonThemeData _segmentedButtons(Color ink) =>
    SegmentedButtonThemeData(
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return ink.withValues(alpha: .22);
          }
          if (states.contains(WidgetState.pressed)) {
            return ink.withValues(alpha: .12);
          }
          if (states.contains(WidgetState.hovered)) {
            return ink.withValues(alpha: .06);
          }
          return null;
        }),
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
  Color get ink => dark ? _darkInk : JotterColors.ink;
  Color get muted => dark ? const Color(0xFFB0B7AB) : JotterColors.muted;
  Color get line => dark ? const Color(0xFF3D453E) : JotterColors.line;
  Color get selected =>
      dark ? const Color(0xFF323B33) : const Color(0xFFE7E5DC);

  /// Dark mode keeps a pastel's hue at a dark lightness; blending it into the
  /// paper made every note colour the same grey.
  Color tint(Color color) {
    if (!dark) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < .05) return Color.lerp(color, paper, .85)!;
    return hsl
        .withSaturation(hsl.saturation.clamp(0, .32))
        .withLightness(.21)
        .toColor();
  }
}

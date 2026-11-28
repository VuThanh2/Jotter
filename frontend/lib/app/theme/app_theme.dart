import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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
  static const sky = Color(0xFFE4EEF5);
}

/// One set of durations and curves so every screen moves the same way.
abstract final class JotterMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 380);
  static const curve = Curves.easeOutCubic;
}

/// The app's typeface, bundled so web and phones look the same offline.
const kJotterFont = 'BeVietnamPro';

const _darkPaper = Color(0xFF1B201D);
const _darkSidebar = Color(0xFF212823);
const _darkSurface = Color(0xFF242B25);
const _darkRaised = Color(0xFF2B332D);
const _darkLine = Color(0xFF3B433C);
const _darkInk = Color(0xFFE5E7DF);
const _darkMuted = Color(0xFFB0B7AB);
const _darkAccent = Color(0xFFE38D70);

final jotterTheme = _buildTheme(Brightness.light);
final jotterDarkTheme = _buildTheme(Brightness.dark);

const _textTheme = TextTheme(
  headlineLarge: TextStyle(
    fontFamily: kJotterFont,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
  ),
  headlineMedium: TextStyle(
    fontFamily: kJotterFont,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -.8,
  ),
  headlineSmall: TextStyle(
    fontFamily: kJotterFont,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -.5,
  ),
  titleLarge: TextStyle(
    fontFamily: kJotterFont,
    fontSize: 21,
    fontWeight: FontWeight.w600,
    letterSpacing: -.4,
  ),
  titleMedium: TextStyle(
    fontFamily: kJotterFont,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -.1,
  ),
  titleSmall: TextStyle(
    fontFamily: kJotterFont,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  ),
  bodyLarge: TextStyle(fontFamily: kJotterFont, fontSize: 16, height: 1.6),
  bodyMedium: TextStyle(fontFamily: kJotterFont, fontSize: 14.5, height: 1.5),
  bodySmall: TextStyle(fontFamily: kJotterFont, fontSize: 12.5, height: 1.5),
  labelLarge: TextStyle(
    fontFamily: kJotterFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  ),
  labelMedium: TextStyle(
    fontFamily: kJotterFont,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
  ),
  labelSmall: TextStyle(
    fontFamily: kJotterFont,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: .3,
  ),
);

ThemeData _buildTheme(Brightness brightness) {
  final palette = JotterPalette(brightness == Brightness.dark);
  final dark = palette.dark;
  final ink = palette.ink;
  final muted = palette.muted;
  final line = palette.line;
  final accent = palette.accent;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: JotterColors.accent,
        brightness: brightness,
      ).copyWith(
        primary: accent,
        onPrimary: dark ? const Color(0xFF3A160A) : Colors.white,
        primaryContainer: palette.accentSoft,
        onPrimaryContainer: dark
            ? const Color(0xFFFFDBCF)
            : const Color(0xFF6B2A16),
        surface: palette.paper,
        onSurface: ink,
        onSurfaceVariant: muted,
        outline: line,
        outlineVariant: line,
        surfaceTint: Colors.transparent,
        surfaceContainerLowest: palette.surface,
        surfaceContainerLow: dark
            ? const Color(0xFF1F2621)
            : const Color(0xFFF6F5F1),
        surfaceContainer: palette.sidebar,
        surfaceContainerHigh: palette.selected,
        surfaceContainerHighest: dark
            ? const Color(0xFF39423A)
            : const Color(0xFFE1DFD6),
      );
  final text = _textTheme.apply(bodyColor: ink, displayColor: ink);
  final overlay = palette.dialog;
  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: kJotterFont,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.paper,
    canvasColor: dark ? overlay : Colors.white,
    cardColor: palette.surface,
    dividerColor: line,
    textTheme: text.copyWith(bodySmall: text.bodySmall?.copyWith(color: muted)),
    // Ink wells (navigation, menus, cards) show keyboard focus with this.
    focusColor: ink.withValues(alpha: dark ? .2 : .16),
    hoverColor: ink.withValues(alpha: .045),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: _SoftPageTransitionsBuilder(),
        TargetPlatform.windows: _SoftPageTransitionsBuilder(),
        TargetPlatform.linux: _SoftPageTransitionsBuilder(),
        TargetPlatform.fuchsia: _SoftPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      // Lifts off the page only once content scrolls under it.
      backgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.scrolledUnder)
            ? palette.sidebar
            : palette.paper,
      ),
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 4,
      titleTextStyle: text.titleMedium?.copyWith(fontSize: 18),
      iconTheme: IconThemeData(color: ink, size: 22),
      actionsIconTheme: IconThemeData(color: ink, size: 22),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: palette.paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: palette.accentSoft,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: kJotterFont,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? ink : muted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: palette.sidebar,
      indicatorColor: palette.accentSoft,
      useIndicator: true,
      selectedIconTheme: IconThemeData(color: accent, size: 23),
      unselectedIconTheme: IconThemeData(color: muted, size: 23),
      selectedLabelTextStyle: TextStyle(
        fontFamily: kJotterFont,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: kJotterFont,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: scheme.onPrimary,
      elevation: 3,
      focusElevation: 4,
      hoverElevation: 5,
      highlightElevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: const TextStyle(
        fontFamily: kJotterFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF262D27) : Colors.white,
      hoverColor: ink.withValues(alpha: .02),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: outline(line),
      enabledBorder: outline(line),
      disabledBorder: outline(line.withValues(alpha: .6)),
      focusedBorder: outline(accent, 1.6),
      errorBorder: outline(scheme.error),
      focusedErrorBorder: outline(scheme.error, 1.6),
      hintStyle: TextStyle(fontFamily: kJotterFont, color: muted, fontSize: 14),
      labelStyle: TextStyle(
        fontFamily: kJotterFont,
        color: muted,
        fontSize: 14,
      ),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          fontFamily: kJotterFont,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.error)
              ? scheme.error
              : states.contains(WidgetState.focused)
              ? accent
              : muted,
        ),
      ),
      helperStyle: TextStyle(
        fontFamily: kJotterFont,
        color: muted,
        fontSize: 12,
      ),
      errorStyle: const TextStyle(fontFamily: kJotterFont, fontSize: 12),
      prefixIconColor: muted,
      suffixIconColor: muted,
    ),
    cardTheme: _cards(fill: palette.surface, line: line),
    dialogTheme: DialogThemeData(
      backgroundColor: overlay,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .25),
      barrierColor: Colors.black.withValues(alpha: dark ? .55 : .32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium?.copyWith(color: muted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: overlay,
      modalBackgroundColor: overlay,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: muted.withValues(alpha: .45),
      dragHandleSize: const Size(36, 4),
      modalBarrierColor: Colors.black.withValues(alpha: dark ? .55 : .32),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: .2),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: line),
      ),
      textStyle: text.bodyMedium,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surface,
      selectedColor: palette.accentSoft,
      checkmarkColor: accent,
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected)
              ? accent.withValues(alpha: .35)
              : line,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(
        fontFamily: kJotterFont,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      iconTheme: IconThemeData(color: muted, size: 16),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: ink,
      titleTextStyle: TextStyle(
        fontFamily: kJotterFont,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: kJotterFont,
        fontSize: 12.5,
        height: 1.35,
        color: muted,
      ),
      minLeadingWidth: 24,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: BorderSide(color: muted, width: 1.5),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: accent.withValues(alpha: .12),
      circularTrackColor: Colors.transparent,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: accent.withValues(alpha: .16),
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: .12),
      valueIndicatorColor: ink,
      valueIndicatorTextStyle: TextStyle(
        fontFamily: kJotterFont,
        color: palette.paper,
      ),
      trackHeight: 4,
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: accent,
      textColor: scheme.onPrimary,
      textStyle: const TextStyle(
        fontFamily: kJotterFont,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(8),
      thumbColor: WidgetStatePropertyAll(ink.withValues(alpha: .22)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: .22),
      selectionHandleColor: accent,
    ),
    filledButtonTheme: _filledButtons(ink),
    outlinedButtonTheme: _outlinedButtons(
      ink: ink,
      line: dark ? _outlineDark : line,
    ),
    textButtonTheme: _textButtons(ink),
    iconButtonTheme: _iconButtons(ink),
    segmentedButtonTheme: _segmentedButtons(palette),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      textStyle: TextStyle(
        fontFamily: kJotterFont,
        fontSize: 12,
        color: palette.paper,
      ),
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      backgroundColor: ink,
      // Inherited, a light snackbar showed dark text on dark.
      contentTextStyle: TextStyle(
        fontFamily: kJotterFont,
        fontSize: 14,
        color: palette.paper,
      ),
      actionTextColor: dark ? JotterColors.accent : const Color(0xFFF4B59E),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

const _outlineDark = Color(0xFF65705F);

/// Flat like note cards; Material's default takes a reddish seed tint.
CardThemeData _cards({required Color fill, required Color line}) =>
    CardThemeData(
      color: fill,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
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
    textStyle: const TextStyle(
      fontFamily: kJotterFont,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
  ).copyWith(side: _focusRing(ring)),
);

OutlinedButtonThemeData _outlinedButtons({
  required Color ink,
  required Color line,
}) => OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    foregroundColor: ink,
    textStyle: const TextStyle(
      fontFamily: kJotterFont,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    minimumSize: const Size(44, 44),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
  ).copyWith(side: _focusRing(ink, BorderSide(color: line))),
);

TextButtonThemeData _textButtons(Color ring) => TextButtonThemeData(
  style: TextButton.styleFrom(
    textStyle: const TextStyle(
      fontFamily: kJotterFont,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ).copyWith(side: _focusRing(ring)),
);

IconButtonThemeData _iconButtons(Color ring) =>
    IconButtonThemeData(style: ButtonStyle(side: _focusRing(ring)));

/// Segments share one outline, so focus shows as a stronger fill instead.
SegmentedButtonThemeData _segmentedButtons(JotterPalette palette) {
  final ink = palette.ink;
  return SegmentedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      side: WidgetStatePropertyAll(BorderSide(color: palette.line)),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.accentSoft
            : palette.surface,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? (palette.dark ? const Color(0xFFFFDBCF) : const Color(0xFF7A2F18))
            : ink,
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: kJotterFont,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
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
}

/// Web and desktop: the new page rises a few pixels while it fades in,
/// quicker and calmer than the phone-style zoom.
class _SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .015),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

extension JotterPaletteContext on BuildContext {
  JotterPalette get jotterColors =>
      JotterPalette(Theme.of(this).brightness == Brightness.dark);
}

/// Tones for notices: info, success, warning and error.
enum JotterTone { info, success, warning, error }

class JotterPalette {
  const JotterPalette(this.dark);
  final bool dark;
  Color get paper => dark ? _darkPaper : JotterColors.paper;
  Color get sidebar => dark ? _darkSidebar : JotterColors.sidebar;
  Color get ink => dark ? _darkInk : JotterColors.ink;
  Color get muted => dark ? _darkMuted : JotterColors.muted;
  Color get line => dark ? _darkLine : JotterColors.line;
  Color get selected =>
      dark ? const Color(0xFF323B33) : const Color(0xFFE7E5DC);

  /// Cards and fields that sit on the page.
  Color get surface => dark ? _darkSurface : Colors.white;

  /// Menus and popovers that float above cards.
  Color get raised => dark ? _darkRaised : Colors.white;

  /// Dialogs and sheets.
  Color get dialog => dark ? const Color(0xFF222923) : JotterColors.paper;

  /// Accent that stays readable on [paper] in both modes.
  Color get accent => dark ? _darkAccent : JotterColors.accent;

  /// A soft accent wash for selected states and highlights.
  Color get accentSoft =>
      dark ? const Color(0xFF4A2E25) : const Color(0xFFF7E4DA);

  /// Soft shadow for raised cards; deeper in dark mode to stay visible.
  List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? .32 : .07),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  ({Color background, Color border, Color foreground, Color icon}) tone(
    JotterTone tone,
  ) => switch (tone) {
    JotterTone.info => (
      background: dark ? const Color(0xFF2A322C) : const Color(0xFFF0EFE9),
      border: dark ? const Color(0xFF3B443D) : const Color(0xFFE3E1D8),
      foreground: ink,
      icon: muted,
    ),
    JotterTone.success => (
      background: dark ? const Color(0xFF213325) : const Color(0xFFEAF3E6),
      border: dark ? const Color(0xFF2F4B34) : const Color(0xFFCFE2C8),
      foreground: dark ? const Color(0xFFCDE8C8) : const Color(0xFF24502C),
      icon: dark ? const Color(0xFF8FCB94) : const Color(0xFF3F8A4A),
    ),
    JotterTone.warning => (
      background: dark ? const Color(0xFF352E1D) : const Color(0xFFFBF3DF),
      border: dark ? const Color(0xFF524528) : const Color(0xFFEEDDB2),
      foreground: dark ? const Color(0xFFF0DFB4) : const Color(0xFF654A0E),
      icon: dark ? const Color(0xFFE3BF67) : const Color(0xFFA27718),
    ),
    JotterTone.error => (
      background: dark ? const Color(0xFF3A2320) : const Color(0xFFFCECE8),
      border: dark ? const Color(0xFF5B332D) : const Color(0xFFF3CFC6),
      foreground: dark ? const Color(0xFFFFD6CC) : const Color(0xFF8A2A17),
      icon: dark ? const Color(0xFFFF9C86) : const Color(0xFFC0432A),
    ),
  };

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

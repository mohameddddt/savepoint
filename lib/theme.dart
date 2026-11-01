import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Core palette — "midnight arcade": warm ink blacks, bone-white text,
/// one switchable signal accent, plus fixed status hues.
class C {
  static const bg = Color(0xFF0B0A0F);
  static const surface = Color(0xFF14131A);
  static const raised = Color(0xFF1C1B24);
  static const high = Color(0xFF26242F);
  static const line = Color(0xFF2A2833);
  static const text = Color(0xFFF4F0E8);
  static const sub = Color(0xFFB8B3C3);
  static const muted = Color(0xFF7B7687);
  static const faint = Color(0xFF4B4756);
  static const gold = Color(0xFFFFC53D);
  static const heart = Color(0xFFFF4D6D);
}

class Accent {
  final String name;
  final Color color;
  final Color ink;
  const Accent(this.name, this.color, this.ink);
}

const accents = <Accent>[
  Accent('Ember', Color(0xFFFF5B3A), Color(0xFF1C0904)),
  Accent('Volt', Color(0xFFC6F33F), Color(0xFF141C02)),
  Accent('Plasma', Color(0xFFFF4FA3), Color(0xFF22030F)),
  Accent('Ion', Color(0xFF43D3FF), Color(0xFF02161D)),
  Accent('Ultra', Color(0xFF9D7CFF), Color(0xFF0F0624)),
  Accent('Solar', Color(0xFFFFB627), Color(0xFF1F1300)),
];

class T {
  static const display = 'Bricolage';
  static const body = 'Jakarta';
  static const mono = 'Mono';

  static const hero = TextStyle(fontFamily: display, fontSize: 40, fontWeight: FontWeight.w800, height: 0.95, letterSpacing: -1.6, color: C.text);
  static const h1 = TextStyle(fontFamily: display, fontSize: 32, fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -1.1, color: C.text);
  static const h2 = TextStyle(fontFamily: display, fontSize: 23, fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -0.6, color: C.text);
  static const h3 = TextStyle(fontFamily: display, fontSize: 18, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.3, color: C.text);
  static const title = TextStyle(fontFamily: body, fontSize: 15, fontWeight: FontWeight.w700, height: 1.25, color: C.text);
  static const body1 = TextStyle(fontFamily: body, fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.55, color: C.sub);
  static const small = TextStyle(fontFamily: body, fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.35, color: C.muted);
  static const label = TextStyle(fontFamily: mono, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.3, height: 1.2, color: C.muted);
  static const num = TextStyle(fontFamily: display, fontSize: 30, fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -1, color: C.text);
}

ThemeData buildTheme(Accent a) {
  final scheme = ColorScheme.fromSeed(seedColor: a.color, brightness: Brightness.dark).copyWith(
    primary: a.color,
    onPrimary: a.ink,
    secondary: a.color,
    onSecondary: a.ink,
    surface: C.surface,
    onSurface: C.text,
    surfaceContainerHighest: C.high,
    surfaceContainerHigh: C.raised,
    surfaceContainer: C.raised,
    surfaceContainerLow: C.surface,
    outline: C.line,
    outlineVariant: C.line,
    error: const Color(0xFFFF5D5D),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    fontFamily: T.body,
    splashFactory: InkRipple.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: const TextTheme(
      bodyMedium: T.body1,
      bodyLarge: TextStyle(fontFamily: T.body, fontSize: 15, color: C.text),
      titleMedium: T.title,
    ).apply(bodyColor: C.text, displayColor: C.text),
    textSelectionTheme: TextSelectionThemeData(cursorColor: a.color, selectionColor: a.color.withValues(alpha: 0.35), selectionHandleColor: a.color),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: T.h3,
      systemOverlayStyle: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: C.bg),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: C.surface,
      showDragHandle: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: C.raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(26))),
      titleTextStyle: T.h3,
      contentTextStyle: T.body1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: C.high,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: C.line),
      ),
      textStyle: const TextStyle(fontFamily: T.body, fontWeight: FontWeight.w600, color: C.text, fontSize: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: C.text,
      contentTextStyle: const TextStyle(fontFamily: T.body, color: C.bg, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actionTextColor: a.color == accents[1].color ? const Color(0xFF4C6B00) : a.color,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.raised,
      hintStyle: const TextStyle(color: C.muted, fontWeight: FontWeight.w500),
      labelStyle: const TextStyle(color: C.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: C.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: a.color, width: 1.4),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? a.ink : C.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? a.color : C.high),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: a.color, inactiveTrackColor: C.high, thumbColor: a.color, overlayColor: a.color.withValues(alpha: 0.15)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: a.color, linearTrackColor: C.high),
    dividerTheme: const DividerThemeData(color: C.line, thickness: 1, space: 1),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder(backgroundColor: C.bg)}),
  );
}

extension ThemeX on BuildContext {
  Color get accent => Theme.of(this).colorScheme.primary;
  Color get onAccent => Theme.of(this).colorScheme.onPrimary;
}

part of 'app.dart';

const _bg = Color(0xFF101316);
const _panel = Color(0xFF191D21);
const _panel2 = Color(0xFF23282D);
const _border = Color(0xFF343B41);
const _accent = Color(0xFFE7A34A);
const _muted = Color(0xFFB0BAC1);
const _subtle = Color(0xFF87939B);

ThemeData buildAppTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: _bg,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _accent,
    brightness: Brightness.dark,
    surface: _panel,
    primary: _accent,
    onSurface: const Color(0xFFF1F3F4),
  ),
  dividerColor: _border,
  visualDensity: VisualDensity.standard,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize: 14, height: 1.4),
    bodyMedium: TextStyle(fontSize: 13, height: 1.4),
    bodySmall: TextStyle(fontSize: 12, height: 1.35, color: _muted),
    titleLarge: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _panel2,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: _accent, width: 1.3),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    hintStyle: const TextStyle(color: _subtle, fontSize: 13),
    labelStyle: const TextStyle(color: _muted, fontSize: 13),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _accent,
      foregroundColor: const Color(0xFF1D1710),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFE6EAED),
      side: const BorderSide(color: _border),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: _panel2,
    selectedColor: const Color(0xFF41301C),
    side: const BorderSide(color: _border),
    labelStyle: const TextStyle(fontSize: 12),
    padding: const EdgeInsets.symmetric(horizontal: 7),
  ),
  useMaterial3: true,
);

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'preferred_theme';
  static const String _fontSizeKey = 'terminal_font_size';
  
  String _currentTheme = 'Dark';
  double _terminalFontSize = 14.0;

  String get currentTheme => _currentTheme;
  double get terminalFontSize => _terminalFontSize;

  bool get isLight => _currentTheme == 'Light';
  bool get isDarkBg => _currentTheme != 'Light';

  ThemeProvider() {
    _loadTheme();
    _loadFontSize();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTheme = prefs.getString(_themeKey) ?? 'Dark';
    notifyListeners();
  }

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    _terminalFontSize = prefs.getDouble(_fontSizeKey) ?? 14.0;
    notifyListeners();
  }

  Future<void> setTheme(String themeName) async {
    _currentTheme = themeName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeName);
  }

  Future<void> setFontSize(double size) async {
    if (size < 8 || size > 30) return;
    _terminalFontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
  }

  void increaseFontSize() => setFontSize(_terminalFontSize + 1);
  void decreaseFontSize() => setFontSize(_terminalFontSize - 1);

  ThemeData getAppTheme() {
    final baseTheme = _getThemeData();
    final displayTheme = GoogleFonts.spaceGroteskTextTheme(baseTheme.textTheme);
    final bodyTheme = GoogleFonts.dmSansTextTheme(displayTheme);

    return baseTheme.copyWith(
      textTheme: bodyTheme.copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(
          textStyle: bodyTheme.displayLarge,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.6,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          textStyle: bodyTheme.displayMedium,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          textStyle: bodyTheme.headlineLarge,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          textStyle: bodyTheme.headlineMedium,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          textStyle: bodyTheme.titleLarge,
          fontWeight: FontWeight.w700,
        ),
        labelLarge: GoogleFonts.jetBrainsMono(
          textStyle: bodyTheme.labelLarge,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
        labelMedium: GoogleFonts.jetBrainsMono(
          textStyle: bodyTheme.labelMedium,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  ThemeData _getThemeData() {
    switch (_currentTheme) {
      case 'Light':
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF1565FF),
            onPrimary: Colors.white,
            secondary: Color(0xFF00B8D9),
            onSecondary: Color(0xFF04111F),
            error: Color(0xFFD64545),
            onError: Colors.white,
            surface: Color(0xFFF4F7FB),
            onSurface: Color(0xFF0D1B2A),
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F7FB),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: Color(0xFFF4F7FB),
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: Color(0xFF0D1B2A),
          ),
          cardTheme: const CardThemeData(
            elevation: 0,
            color: Color(0xFFFFFFFF),
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              backgroundColor: const Color(0xFF1565FF),
              foregroundColor: Colors.white,
              textStyle: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0x190D1B2A)),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0x140D1B2A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF1565FF), width: 1.5),
            ),
          ),
        );
      case 'Matrix':
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0XFF00FF00),
            brightness: Brightness.dark,
            primary: const Color(0XFF00FF00),
            surface: const Color(0XFF050505),
          ),
          scaffoldBackgroundColor: const Color(0XFF050505),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: Color(0xFF001A00),
            elevation: 0,
            foregroundColor: Color(0XFF00FF00),
          ),
          cardTheme: const CardThemeData(
            elevation: 0,
            color: Colors.black,
          ),
        );
      case 'Ubuntu':
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0XFFDD4814),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0XFF300A24),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: Color(0xFF4C1032),
            elevation: 0,
          ),
        );
      case 'Dark':
      default:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme(
            brightness: Brightness.dark,
            primary: Color(0xFF67E8F9),
            onPrimary: Color(0xFF03141B),
            secondary: Color(0xFF4F7CFF),
            onSecondary: Colors.white,
            error: Color(0xFFFF6B6B),
            onError: Color(0xFF1C0F10),
            surface: Color(0xFF0F1722),
            onSurface: Color(0xFFF3F7FF),
          ),
          scaffoldBackgroundColor: const Color(0xFF060B13),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          cardTheme: const CardThemeData(
            elevation: 0,
            color: Color(0xFF0F1722),
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              backgroundColor: const Color(0xFF67E8F9),
              foregroundColor: const Color(0xFF03141B),
              textStyle: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0x1F67E8F9)),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              foregroundColor: const Color(0xFFE5F4FF),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF0C1320),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0x1F67E8F9)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF67E8F9), width: 1.5),
            ),
          ),
          dividerTheme: const DividerThemeData(color: Color(0x1F8AA3C2)),
        );
    }
  }
}

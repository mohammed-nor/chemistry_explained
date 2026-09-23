import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/molecule_editor.dart';

void main() {
  runApp(const MolDrawApp());
}

class MolDrawApp extends StatefulWidget {
  const MolDrawApp({super.key});

  @override
  State<MolDrawApp> createState() => _MolDrawAppState();
}

class _MolDrawAppState extends State<MolDrawApp> {
  static const String _themeKey = 'mol_draw_theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);

    if (!mounted) return;

    setState(() {
      switch (savedTheme) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
        default:
          _themeMode = ThemeMode.dark;
          break;
      }
    });
  }

  Future<void> _handleThemeChanged(bool isDark) async {
    final nextTheme = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      nextTheme == ThemeMode.dark ? 'dark' : 'light',
    );

    if (!mounted) return;

    setState(() {
      _themeMode = nextTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: MaterialApp(
        title: 'MolDraw',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeData.light().copyWith(
          scaffoldBackgroundColor: const Color(0xFFF2F4F7),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        darkTheme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0E0E0E),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        home: MoleculeEditorScreen(
          themeMode: _themeMode,
          onThemeChanged: _handleThemeChanged,
        ),
      ),
    );
  }
}

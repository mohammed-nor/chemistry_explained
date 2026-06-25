import 'package:flutter/material.dart';
import 'screens/molecule_editor.dart';

void main() {
  runApp(const MolDrawApp());
}

class MolDrawApp extends StatelessWidget {
  const MolDrawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MolDraw',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E0E0E),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      home: const MoleculeEditorScreen(),
    );
  }
}

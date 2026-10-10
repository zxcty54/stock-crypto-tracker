import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/rentals/screens/app_shell.dart';

abstract final class AanganColors {
  static const forest = Color(0xFF1E4B3D);
  static const forestDark = Color(0xFF173C31);
  static const leaf = Color(0xFF6D927A);
  static const terracotta = Color(0xFFD97757);
  static const gold = Color(0xFFE2B66F);
  static const canvas = Color(0xFFF6F6F1);
  static const cream = Color(0xFFFFFCF5);
  static const ink = Color(0xFF1E2A23);
  static const muted = Color(0xFF78837A);
  static const line = Color(0xFFE5E9E2);
  static const paleGreen = Color(0xFFEAF1E9);
  static const paleOrange = Color(0xFFFFF0E8);
  static const danger = Color(0xFFB64F43);
}

class AanganApp extends StatelessWidget {
  const AanganApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AanganColors.forest,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AanganColors.canvas,
      textTheme: GoogleFonts.dmSansTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AanganColors.canvas,
        foregroundColor: AanganColors.ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(color: AanganColors.muted, fontSize: 14),
        labelStyle: const TextStyle(color: AanganColors.muted, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AanganColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AanganColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AanganColors.forest, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AanganColors.danger),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AanganColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: AanganColors.line,
    );

    return MaterialApp(
      title: 'Aangan — Bihar rentals',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(
          bodyColor: AanganColors.ink,
          displayColor: AanganColors.ink,
        ),
      ),
      home: const AppShell(),
    );
  }
}

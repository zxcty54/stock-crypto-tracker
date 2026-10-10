import 'package:flutter/material.dart';

const ink = Color(0xFF16372A);
const green = Color(0xFF19764E);
const muted = Color(0xFF6D7D73);
const canvas = Color(0xFFF7F9F5);
const line = Color(0xFFE2E9E1);
const amber = Color(0xFFF0B64D);
ThemeData marketTheme() => ThemeData(
  useMaterial3: true, fontFamily: 'Manrope', scaffoldBackgroundColor: canvas,
  colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green, surface: Colors.white),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: ink, fontSize: 40, fontWeight: FontWeight.w800, height: 1.16),
    headlineMedium: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w800),
    titleLarge: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800),
    titleMedium: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(color: ink, fontSize: 15, height: 1.6),
    bodyMedium: TextStyle(color: ink, fontSize: 13, height: 1.5),
    bodySmall: TextStyle(color: muted, fontSize: 11, height: 1.5),
  ),
  cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: line))),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
    minimumSize: const Size(48, 46), textStyle: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 13),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
  outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
    minimumSize: const Size(48, 46), side: const BorderSide(color: line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
  inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: green, width: 1.5))),
  dividerColor: line, snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
);

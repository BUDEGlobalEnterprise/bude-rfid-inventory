import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  AppTypography._();

  static TextTheme get textTheme => GoogleFonts.interTextTheme(
        const TextTheme(
          // Dense data sizes — important for inventory lists on small screens
          bodySmall: TextStyle(fontSize: 11, letterSpacing: 0.2),
          bodyMedium: TextStyle(fontSize: 13, letterSpacing: 0.1),
          bodyLarge: TextStyle(fontSize: 15),
          labelSmall: TextStyle(fontSize: 10, letterSpacing: 0.5),
          labelMedium: TextStyle(fontSize: 12, letterSpacing: 0.4),
          labelLarge: TextStyle(fontSize: 14, letterSpacing: 0.1),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      );
}

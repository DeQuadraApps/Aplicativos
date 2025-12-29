// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ===================================
// PALETA DE CORES - TEMA CLARO
// ===================================
class AppColorsLight {
  static const Color background = Color(0xFFF5F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF2D3748);
  static const Color secondary = Color(0xFF718096);
  static const Color textPrimary = Color(0xFF1A202C);
  static const Color error = Color(0xFFE53E3E);
}

// ===================================
// NOVA PALETA DE CORES - TEMA ESCURO
// ===================================
class AppColorsDark {
  static const Color background = Color(0xFF1A202C); // Chumbo bem escuro
  static const Color surface = Color(0xFF2D3748);    // Chumbo um pouco mais claro
  static const Color primary = Color(0xFF81E6D9);    // Um verde-água/ciano para contraste
  static const Color secondary = Color(0xFFA0AEC0);  // Cinza claro para textos secundários
  static const Color textPrimary = Color(0xFFEDF2F7); // Branco suave para textos principais
  static const Color error = Color(0xFFFC8181);      // Vermelho claro para erros
}

class AppTheme {

  // =========================
  // TEMA CLARO (LIGHT THEME)
  // =========================
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColorsLight.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColorsLight.primary,
        brightness: Brightness.light,
        background: AppColorsLight.background,
        surface: AppColorsLight.surface,
        primary: AppColorsLight.primary,
        secondary: AppColorsLight.secondary,
        error: AppColorsLight.error,
        onSurface: AppColorsLight.textPrimary, // Cor do texto sobre a superfície
      ),
      useMaterial3: true,
      textTheme: _buildTextTheme(AppColorsLight.textPrimary, AppColorsLight.secondary),
      elevatedButtonTheme: _buildElevatedButtonTheme(AppColorsLight.primary, Colors.white),
      inputDecorationTheme: _buildInputDecorationTheme(
        surfaceColor: AppColorsLight.surface,
        primaryColor: AppColorsLight.primary,
        secondaryColor: AppColorsLight.secondary,
        errorColor: AppColorsLight.error,
      ),
      appBarTheme: const AppBarTheme(
        scrolledUnderElevation: 0,
        surfaceTintColor: AppColorsLight.surface,
        backgroundColor: AppColorsLight.surface,
      ),
      // ... outras customizações do tema claro
    );
  }

  // =========================
  // TEMA ESCURO (DARK THEME)
  // =========================
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColorsDark.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColorsDark.primary,
        brightness: Brightness.dark,
        background: AppColorsDark.background,
        surface: AppColorsDark.surface,
        primary: AppColorsDark.primary,
        secondary: AppColorsDark.secondary,
        error: AppColorsDark.error,
        onSurface: AppColorsDark.textPrimary, // Cor do texto sobre a superfície
      ),
      useMaterial3: true,
      textTheme: _buildTextTheme(AppColorsDark.textPrimary, AppColorsDark.secondary),
      elevatedButtonTheme: _buildElevatedButtonTheme(AppColorsDark.primary, AppColorsDark.background),
      inputDecorationTheme: _buildInputDecorationTheme(
        surfaceColor: AppColorsDark.surface,
        primaryColor: AppColorsDark.primary,
        secondaryColor: AppColorsDark.secondary,
        errorColor: AppColorsDark.error,
      ),
      appBarTheme: const AppBarTheme(
        scrolledUnderElevation: 0,
        surfaceTintColor: AppColorsDark.surface,
        backgroundColor: AppColorsDark.surface,
      ),
      // ... outras customizações do tema escuro
    );
  }

  // =========================
  // MÉTODOS HELPER REUTILIZÁVEIS
  // =========================

  static TextTheme _buildTextTheme(Color primaryTextColor, Color secondaryTextColor) {
    return TextTheme(
      displayLarge: GoogleFonts.poppins(fontSize: 57, fontWeight: FontWeight.w800, color: primaryTextColor),
      headlineLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: primaryTextColor),
      headlineMedium: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w600, color: primaryTextColor, letterSpacing: 0.5),
      titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: primaryTextColor),
      titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: primaryTextColor, letterSpacing: 0.15),
      bodyLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w400, color: primaryTextColor),
      bodyMedium: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w400, color: secondaryTextColor),
      labelLarge: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600), // Cor será definida pelo botão
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(Color backgroundColor, Color foregroundColor) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme({
    required Color surfaceColor,
    required Color primaryColor,
    required Color secondaryColor,
    required Color errorColor,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: GoogleFonts.poppins(color: secondaryColor, fontSize: 14),
      hintStyle: GoogleFonts.poppins(color: secondaryColor.withOpacity(0.7), fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorColor, width: 2.0),
      ),
    );
  }
}
// lib/main.dart
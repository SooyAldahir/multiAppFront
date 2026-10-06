import 'package:flutter/material.dart';

/// Colores tomados del mockup de Figma (App Mockup Ideas).
class AppColors {
  AppColors._();

  static const background = Color(0xFFF8F8FA);
  static const surface = Colors.white;
  static const ink = Color(0xFF222129);
  static const inkSoft = Color(0xFF393641);
  static const muted = Color(0xFF92919B);
  static const mutedLight = Color(0xFFAAA9B1);
  static const border = Color(0xFFE8E7EC);
  static const chip = Color(0xFFEEEEF2);

  static const primary = Color(0xFF6B59DD);
  static const primaryText = Color(0xFF7462D3);
  static const primarySoft = Color(0xFFF0EDFC);
  static const primaryBorder = Color(0xFFDFDAF3);

  static const darkCardStart = Color(0xFF302B3B);
  static const darkCardEnd = Color(0xFF1D1C22);
  static const glow = Color(0xFF735CE5);
  static const orbStart = Color(0xFF8A76EE);
  static const orbEnd = Color(0xFF5B48C2);
  static const fab = Color(0xFF28262E);

  static const danger = Color(0xFFFF625F);
  static const success = Color(0xFF53B981);
  static const priorityHighBg = Color(0xFFFFF0EE);
  static const priorityHigh = Color(0xFFD96B60);
}

/// Par de colores (fondo suave + color fuerte) para los íconos de cada módulo.
class ModuleTint {
  const ModuleTint(this.background, this.foreground);
  final Color background;
  final Color foreground;

  static const violet = ModuleTint(Color(0xFFEEEAFE), Color(0xFF6B59DD));
  static const blue = ModuleTint(Color(0xFFE7F1FF), Color(0xFF4385D6));
  static const coral = ModuleTint(Color(0xFFFFF0EB), Color(0xFFDF6A4E));
  static const amber = ModuleTint(Color(0xFFFFF4D9), Color(0xFFCA901F));
  static const teal = ModuleTint(Color(0xFFE3F5F1), Color(0xFF358C7E));
  static const ink = ModuleTint(Color(0xFFE9E9ED), Color(0xFF373640));
  static const green = ModuleTint(Color(0xFFE9F7E8), Color(0xFF4D994F));
  static const pink = ModuleTint(Color(0xFFFDEAF3), Color(0xFFCF4F85));

  static const all = [violet, blue, coral, amber, teal, ink, green, pink];
  static const names = ['violet', 'blue', 'coral', 'amber', 'teal', 'ink', 'green', 'pink'];

  /// Convierte el nombre guardado en la BD (columna Color) en un tinte.
  static ModuleTint byName(String? name, {ModuleTint fallback = violet}) {
    final i = names.indexOf(name ?? '');
    return i >= 0 ? all[i] : fallback;
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.mutedLight),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF9C90DF), width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryText,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    );
  }
}

/// Sombra suave usada por las tarjetas del mockup.
const softShadow = [
  BoxShadow(color: Color(0x0A272435), blurRadius: 20, offset: Offset(0, 7)),
];

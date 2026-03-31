/// ThemeCubit — gestiona el modo de tema de la aplicación
///
/// Responsabilidades:
/// - Mantener el ThemeMode activo (light / dark / system)
/// - Persistir la preferencia con SharedPreferences
/// - Exponer [loadSavedTheme] para leer la preferencia ANTES de runApp
///   y evitar el flash de tema incorrecto al iniciar la app
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  static const String _themeKey = 'app_theme_mode';

  ThemeCubit({ThemeMode initialMode = ThemeMode.dark}) : super(initialMode);

  /// Cambia el tema y persiste la preferencia.
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
    emit(mode);
  }

  /// Lee la preferencia guardada antes de arrancar la app.
  /// Usar en [main()] para pasar el [initialMode] al cubit.
  static Future<ThemeMode> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeKey);
    if (saved == null) return ThemeMode.dark;
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.dark,
    );
  }
}

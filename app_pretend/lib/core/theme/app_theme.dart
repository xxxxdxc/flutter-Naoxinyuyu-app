import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryMain = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color brandPurple = Color(0xFF312E81); // 深蓝紫色品牌色

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  static const Color deviceDbs = Color(0xFF1976D2);
  static const Color deviceHrv = Color(0xFFE91E63);
  static const Color connected = Color(0xFF4CAF50);
  static const Color disconnected = Color(0xFF9E9E9E);

  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFBDBDBD);

  // 模式颜色
  static const Color modeManual = Color(0xFF4FC3F7);      // 浅蓝色
  static const Color modeHrvResponse = Color(0xFFFF9800); // 橙色
  static const Color modeEegResponse = Color(0xFF1976D2); // 深蓝色
  static const Color modeHybrid = Color(0xFF4CAF50);      // 绿色

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryMain,
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryMain,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(120, 48),
        ),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryMain,
        secondary: primaryLight,
        error: error,
        surface: surface,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: textPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 14, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
        labelSmall: TextStyle(fontSize: 12, color: textSecondary),
      ),
    );
  }
}

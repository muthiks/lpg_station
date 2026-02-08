import 'package:flutter/material.dart';

class AppTheme {
  static Color primaryBlue = const Color.fromRGBO(0, 113, 187, 1);
  static Color primaryOrange = const Color.fromRGBO(242, 100, 33, 1);
  static Color successColor = const Color.fromRGBO(9, 149, 110, 1);
  static Color highlightColor = const Color.fromRGBO(212, 172, 13, 1);
  static Color titleColor = const Color.fromRGBO(255, 255, 255, 1);
  static Color textColor = const .fromRGBO(245, 245, 245, 1);

  /// 🔹 Global scaffold gradient
  static LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryOrange],
  );
}

ThemeData primaryTheme = ThemeData(
  //seed color
  colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryBlue),

  //scaffoldBackgroundColor: AppTheme.primaryOrange,
  appBarTheme: AppBarTheme(
    backgroundColor: AppTheme.primaryBlue,
    foregroundColor: AppTheme.titleColor,
    surfaceTintColor: Colors.transparent,
  ),

  textTheme: TextTheme(
    bodyMedium: TextStyle(
      color: AppTheme.textColor,
      fontSize: 14,
      letterSpacing: 1,
    ),
    headlineMedium: TextStyle(
      color: AppTheme.titleColor,
      fontSize: 15,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
    ),
    titleMedium: TextStyle(
      color: AppTheme.titleColor,
      fontWeight: FontWeight.bold,
      fontSize: 18,
      letterSpacing: 2,
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.transparent.withAlpha(1),
    shadowColor: Colors.transparent,
  ),
);

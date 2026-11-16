import 'package:flutter/material.dart';

class AppTheme {
  //  Bảng màu cố định 
  static const Color scaffoldBackgroundColor = Color(0xFFFAF7F0); 
  static const Color primaryColor = Color(0xFF2E5A36); 
  static const Color appBarColor = Color(0xFFB8D1BA); 
  static const Color cardColor = Color(0xFFFFFFFF); 
  static const Color titleTextColor = Color(0xFF1E3523); 
  static const Color subTextColor = Color(0xFF6B7B6E); 

  //  Màu Badge Trạng thái (Dùng cho các Chip/Container) 
  static const Color healthyBadgeBg = Color(0xFFD4EDDA);
  static const Color healthyBadgeText = Color(0xFF1E5631);
  static const Color sickBadgeBg = Color(0xFFFADBD8);
  static const Color sickBadgeText = Color(0xFFA93226);

  // Cấu hình ThemeData 
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        surface: scaffoldBackgroundColor, 
      ),

      // Cấu hình AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: appBarColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: titleTextColor),
        titleTextStyle: TextStyle(
          color: titleTextColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto', 
        ),
      ),

      // Cấu hình Card 
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0, 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E5E5), width: 1), 
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Cấu hình Nút bấm 
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48), 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // Cấu hình Input Form (Cho Màn hình đăng nhập/đăng ký & Search)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(color: subTextColor),
      ),

      // Cấu hình Text
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: titleTextColor, fontSize: 22, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: titleTextColor, fontSize: 18, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: titleTextColor, fontSize: 16),
        bodyMedium: TextStyle(color: subTextColor, fontSize: 14),
      ),
    );
  }
}
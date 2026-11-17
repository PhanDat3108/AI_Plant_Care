import 'package:flutter/material.dart';

/// Giữ chế độ Sáng/Tối của toàn app.
/// - ProfileScreen ghi vào đây khi người dùng bật/tắt "Chế độ Tối".
/// - MyApp (main.dart) lắng nghe để đổi theme (xem hướng dẫn kèm theo).
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDark => themeMode.value == ThemeMode.dark;

  static void setDark(bool value) {
    themeMode.value = value ? ThemeMode.dark : ThemeMode.light;
  }
}

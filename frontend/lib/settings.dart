import 'dart:io';

class Settings {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const publicKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static bool get hasAuth => supabaseUrl.isNotEmpty && publicKey.isNotEmpty;
  static String get apiUrl {
    const url = String.fromEnvironment('API_BASE_URL');
    if (url.isNotEmpty) return url;
    return Platform.isAndroid
        ? 'http://10.0.2.2:3100/api/v1'
        : 'http://127.0.0.1:3100/api/v1';
  }
}

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _hostKey = 'server_host';
  static const String defaultHost = '192.168.1.100:8000';

  static Future<String> getHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_hostKey) ?? defaultHost;
  }

  static Future<void> setHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
  }
}

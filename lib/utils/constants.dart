import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  static const String defaultServerIp = 'eduhard-backend.onrender.com';
  static String _currentServerIp = defaultServerIp;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentServerIp = prefs.getString('custom_server_ip') ?? defaultServerIp;
  }

  static Future<void> setServerIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_server_ip', ip);
    _currentServerIp = ip;
  }

  static String get serverIp => _currentServerIp;

  static String get baseUrl {
    if (_currentServerIp.contains('onrender.com')) {
      return 'https://$_currentServerIp/api';
    }
    if (!_currentServerIp.startsWith('http://') && !_currentServerIp.startsWith('https://')) {
      return 'http://$_currentServerIp/api';
    }
    return '$_currentServerIp/api';
  }

  static String get mediaUrl {
    if (_currentServerIp.contains('onrender.com')) {
      return 'https://$_currentServerIp';
    }
    if (!_currentServerIp.startsWith('http://') && !_currentServerIp.startsWith('https://')) {
      return 'http://$_currentServerIp';
    }
    return _currentServerIp;
  }
}

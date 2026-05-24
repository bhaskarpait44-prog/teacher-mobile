import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import '../utils/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isPinAuthenticated = false;
  String? _storedPin;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _user != null;
  bool get hasPin => _storedPin != null;
  bool get isPinAuthenticated => _isPinAuthenticated;

  AuthProvider() {
    init();
  }

  Future<void> init() async {
    // Load custom server IP if exists
    final customIp = await _storage.read(key: 'server_ip');
    if (customIp != null) {
      ApiConstants.setServerIp(customIp);
    }

    _token = await _storage.read(key: 'token');
    final userStr = await _storage.read(key: 'user');
    if (userStr != null) {
      _user = jsonDecode(userStr);
    }
    _storedPin = await _storage.read(key: 'user_pin');
    
    if (_token != null) {
      NotificationService.registerToken(_token!);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final userRole = data['data']['user']['role'];
      if (userRole != 'teacher') {
        throw Exception('Access denied. Only teachers can log in here.');
      }

      _token = data['data']['token'];
      _user = data['data']['user'];

      await _storage.write(key: 'token', value: _token);
      await _storage.write(key: 'user', value: jsonEncode(_user));
      
      NotificationService.registerToken(_token!);
      
      notifyListeners();
    } else {
      throw Exception(data['message'] ?? 'Login failed');
    }
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: 'user_pin', value: pin);
    _storedPin = pin;
    _isPinAuthenticated = true;
    notifyListeners();
  }

  bool verifyPin(String pin) {
    if (_storedPin == pin) {
      _isPinAuthenticated = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> updateServerIp(String ip) async {
    await _storage.write(key: 'server_ip', value: ip);
    ApiConstants.setServerIp(ip);
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user');
    // We might want to keep the PIN or delete it. 
    // Usually, if logging out completely, we might want to keep PIN for that device if it's per-user.
    // But for simplicity, let's clear it if the user wants a fresh start.
    // However, the requirement says "future login", which often means quick access.
    // Let's clear everything on logout to be safe.
    await _storage.delete(key: 'user_pin');
    _token = null;
    _user = null;
    _storedPin = null;
    _isPinAuthenticated = false;
    notifyListeners();
  }
}

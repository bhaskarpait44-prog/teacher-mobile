import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _user != null;

  AuthProvider() {
    init();
  }

  Future<void> init() async {
    _token = await _storage.read(key: 'token');
    final userStr = await _storage.read(key: 'user');
    if (userStr != null) {
      _user = jsonDecode(userStr);
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
      
      notifyListeners();
    } else {
      throw Exception(data['message'] ?? 'Login failed');
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _token = null;
    _user = null;
    notifyListeners();
  }
}

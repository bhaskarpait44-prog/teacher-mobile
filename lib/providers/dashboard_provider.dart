import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

class DashboardProvider with ChangeNotifier {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get dashboardData => _dashboardData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDashboardData(String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _dashboardData = data['data'];
      } else if (response.statusCode == 401) {
        _errorMessage = 'Unauthorized';
      } else {
        _errorMessage = 'Failed to load dashboard';
      }
    } catch (e) {
      _errorMessage = 'An error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _dashboardData = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}

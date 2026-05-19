import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

class NoticeProvider with ChangeNotifier {
  List<dynamic> _notices = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  List<dynamic> get notices => _notices;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  Future<void> fetchNotices(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/notices/teacher'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _notices = data['data']['notices'] ?? [];
        _unreadCount = _notices.where((n) => n['is_read'] == false).length;
      }
    } catch (e) {
      debugPrint('Error fetching notices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String token, String noticeId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/notices/$noticeId/teacher/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final index = _notices.indexWhere((n) => n['id'].toString() == noticeId);
        if (index != -1) {
          if (_notices[index]['is_read'] == false) {
             _notices[index]['is_read'] = true;
             _unreadCount = (_unreadCount - 1).clamp(0, 1000);
             notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Error marking notice as read: $e');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

class NoticeProvider with ChangeNotifier {
  List<dynamic> _notices = [];
  bool _isLoading = false;
  int _unreadCount = 0;
  String? _error;

  List<dynamic> get notices => _notices;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;
  String? get error => _error;

  Future<void> fetchNotices(String token) async {
    _isLoading = true;
    _error = null;
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
      } else {
        _error = 'Failed to load notices (Status: ${response.statusCode})';
      }
    } catch (e) {
      _error = 'An error occurred while fetching notices. Please check your connection.';
      debugPrint('Error fetching notices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String token, String noticeId, {String source = 'unified'}) async {
    final index = _notices.indexWhere((n) => n['id'].toString() == noticeId);
    if (index == -1 || _notices[index]['is_read'] == true) return;

    // Optimistic update
    final originalState = _notices[index]['is_read'];
    _notices[index]['is_read'] = true;
    _unreadCount = _notices.where((n) => n['is_read'] == false).length;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/notices/teacher/$noticeId/read?source=$source'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        // Rollback on failure
        _notices[index]['is_read'] = originalState;
        _unreadCount = _notices.where((n) => n['is_read'] == false).length;
        notifyListeners();
      }
    } catch (e) {
      // Rollback on error
      _notices[index]['is_read'] = originalState;
      _unreadCount = _notices.where((n) => n['is_read'] == false).length;
      notifyListeners();
      debugPrint('Error marking notice as read: $e');
    }
  }

  Future<bool> deleteNotice(String token, String noticeId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/notices/teacher/$noticeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _notices.removeWhere((n) => n['id'].toString() == noticeId);
        _unreadCount = _notices.where((n) => n['is_read'] == false).length;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting notice: $e');
    }
    return false;
  }

  Future<void> markAllAsRead(String token) async {
    final unreadNotices = _notices.where((n) => n['is_read'] == false).toList();
    if (unreadNotices.isEmpty) return;

    // Optimistic update
    final originalNotices = jsonDecode(jsonEncode(_notices));
    for (var n in _notices) {
      n['is_read'] = true;
    }
    _unreadCount = 0;
    notifyListeners();

    try {
      await Future.wait(unreadNotices.map((n) => http.post(
        Uri.parse('${ApiConstants.baseUrl}/notices/teacher/${n['id']}/read?source=${n['source'] ?? 'unified'}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      )));
    } catch (e) {
      // Rollback on error
      _notices = originalNotices;
      _unreadCount = _notices.where((n) => n['is_read'] == false).length;
      notifyListeners();
    }
  }
}

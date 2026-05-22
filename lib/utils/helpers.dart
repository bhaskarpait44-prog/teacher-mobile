import 'package:flutter/material.dart';

String formatTime12hr(String? timeStr) {
  if (timeStr == null) return '';
  final parts = timeStr.split(':');
  if (parts.length < 2) return timeStr;
  int hour = int.tryParse(parts[0]) ?? 0;
  int minute = int.tryParse(parts[1]) ?? 0;
  final period = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '$hour:${minute.toString().padLeft(2, '0')} $period';
}

String formatDate(String? dateStr) {
  if (dateStr == null) return '';
  try {
    final dt = DateTime.parse(dateStr);
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) { return dateStr; }
}

Color getStatusColor(String? status, BuildContext context) {
  switch (status) {
    case 'present': return Colors.green;
    case 'absent': return Colors.red;
    case 'late': return Colors.orange;
    case 'half_day': return Colors.blue;
    case 'approved': return Colors.green;
    case 'rejected': return Colors.red;
    case 'pending': return Colors.orange;
    case 'cancelled': return Colors.grey;
    case 'submitted': return Colors.blue;
    case 'complete': return Colors.green;
    case 'partial': return Colors.orange;
    default: return Colors.grey;
  }
}

String getInitials(String name) {
  if (name.isEmpty) return 'T';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) {
    return parts[0][0].toUpperCase();
  }
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

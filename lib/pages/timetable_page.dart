import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  Map<String, List<dynamic>> _timetable = {}; // day -> periods
  String? _errorMessage;
  final List<String> _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

  @override
  void initState() {
    super.initState();
    _fetchTimetable();
  }

  Future<void> _fetchTimetable() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/timetable'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _timetable = Map<String, List<dynamic>>.from(data['data']['timetable'] ?? {});
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load timetable';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _days.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Timetable'),
          bottom: TabBar(
            isScrollable: true,
            tabs: _days.map((day) => Tab(text: day.toUpperCase())).toList(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : TabBarView(
                    children: _days.map((day) => _buildDaySchedule(day)).toList(),
                  ),
      ),
    );
  }

  Widget _buildDaySchedule(String day) {
    final periods = _timetable[day] ?? [];
    if (periods.isEmpty) {
      return const Center(child: Text('No periods scheduled for this day.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: periods.length,
      itemBuilder: (context, index) {
        final period = periods[index];
        return Card(
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(period['start_time'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(period['end_time'] ?? '', style: const TextStyle(fontSize: 10)),
              ],
            ),
            title: Text('${period['subject_name']}'),
            subtitle: Text('${period['class_name']} ${period['section_name']} • Period ${period['period_name']}'),
          ),
        );
      },
    );
  }
}

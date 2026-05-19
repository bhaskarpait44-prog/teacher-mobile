import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  bool _isLoading = true;
  Map<String, List<dynamic>> _timetable = {};
  List<dynamic> _exams = [];
  Map<String, dynamic>? _currentPeriod;
  String? _errorMessage;
  Timer? _timer;
  final List<String> _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

  @override
  void initState() {
    super.initState();
    _fetchTimetable();
    _fetchExams();
    _fetchCurrentPeriod();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchCurrentPeriod());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTimetable() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/timetable'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _timetable = Map<String, List<dynamic>>.from(data['data']['timetable'] ?? {});
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error: $e');
    }
  }

  Future<void> _fetchExams() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/exam-timetable'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _exams = data['data']['exams'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchCurrentPeriod() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/timetable/current-period'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _currentPeriod = data['data']?['period']);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Timetable & Exams'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Weekly'),
              Tab(text: 'Exam Schedule'),
            ],
          ),
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorWidget()
                  : TabBarView(
                      children: [
                        _buildWeeklyTab(),
                        _buildExamsTab(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _fetchTimetable();
                _fetchExams();
                _fetchCurrentPeriod();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTab() {
    return DefaultTabController(
      length: _days.length,
      initialIndex: _getTodayIndex(),
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: _days.map((day) => Tab(text: day.substring(0, 3).toUpperCase())).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: _days.map((day) => _buildDaySchedule(day)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  int _getTodayIndex() {
    final weekday = DateTime.now().weekday; // 1 = Monday, ..., 7 = Sunday
    if (weekday >= 7) return 0; // Default to Monday if Sunday
    return weekday - 1;
  }

  Widget _buildDaySchedule(String day) {
    final periods = _timetable[day] ?? [];
    if (periods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('No periods scheduled for this day.'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: periods.length,
      itemBuilder: (context, index) {
        final period = periods[index];
        final todayIndex = DateTime.now().weekday - 1;
        final isToday = _days.indexOf(day) == todayIndex;
        final bool currentHighlight = _currentPeriod != null &&
            _currentPeriod!['period_name'] == period['period_name'] &&
            isToday;

        final colorScheme = Theme.of(context).colorScheme;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: currentHighlight ? BorderSide(color: colorScheme.primary, width: 2) : BorderSide.none,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(formatTime12hr(period['start_time']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const Icon(Icons.arrow_downward, size: 12),
                  Text(formatTime12hr(period['end_time']), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            title: Text(
              period['subject_name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text('${period['class_name']} ${period['section_name']} • ${period['period_name']}'),
            trailing: currentHighlight
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: colorScheme.error, borderRadius: BorderRadius.circular(8)),
                        child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      if (_currentPeriod!['minutes_remaining'] != null)
                        Text('${_currentPeriod!['minutes_remaining']}m left', style: TextStyle(fontSize: 10, color: colorScheme.error)),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildExamsTab() {
    if (_exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('No upcoming exams scheduled.'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _exams.length,
      itemBuilder: (context, index) {
        final exam = _exams[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(exam['exam_name'] ?? 'Exam', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${exam['subject_name']} • ${exam['class_name']} ${exam['section_name']}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14),
                    const SizedBox(width: 4),
                    Text(formatDate(exam['date'])),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time_rounded, size: 14),
                    const SizedBox(width: 4),
                    Text('${formatTime12hr(exam['start_time'])} - ${formatTime12hr(exam['end_time'])}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}



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

class _TimetablePageState extends State<TimetablePage> with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, List<dynamic>> _timetable = {};
  List<dynamic> _exams = [];
  Map<String, dynamic>? _currentPeriod;
  String? _errorMessage;
  Timer? _timer;
  late TabController _mainTabController;
  late TabController _dayTabController;
  final List<String> _days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  String _selectedClassFilter = 'All';

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _dayTabController = TabController(length: _days.length, vsync: this, initialIndex: _getTodayIndex());
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchCurrentPeriod());
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchTimetable(),
      _fetchExams(),
      _fetchCurrentPeriod(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mainTabController.dispose();
    _dayTabController.dispose();
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
          final rawTimetable = data['data']['timetable'];
          Map<String, List<dynamic>> grouped = {};
          
          if (rawTimetable is List) {
            for (var slot in rawTimetable) {
              final day = slot['day_of_week'].toString().toLowerCase();
              if (!grouped.containsKey(day)) grouped[day] = [];
              grouped[day]!.add(slot);
            }
          }
          _timetable = grouped;
        }
      }
    } catch (e) {
      if (mounted) _errorMessage = 'Error fetching timetable: $e';
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
        if (mounted) _exams = data['data']['timetable'] ?? [];
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
        if (mounted) setState(() => _currentPeriod = data['data']?['current_period']);
      }
    } catch (_) {}
  }

  int _getTodayIndex() {
    final weekday = DateTime.now().weekday;
    if (weekday >= 7) return 0;
    return weekday - 1;
  }

  List<String> _getClasses() {
    final classes = <String>{'All'};
    for (var day in _timetable.values) {
      for (var slot in day) {
        classes.add(slot['class_name'].toString());
      }
    }
    for (var exam in _exams) {
      classes.add(exam['class_name'].toString());
    }
    final sorted = classes.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: const Text('My Schedule', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
        actions: [
          _buildFilterButton(),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _mainTabController,
              indicator: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              labelColor: colorScheme.onPrimary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Routine'),
                Tab(text: 'Exams'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _mainTabController,
                  children: [
                    _buildWeeklyTab(),
                    _buildExamsTab(),
                  ],
                ),
    );
  }

  Widget _buildFilterButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _selectedClassFilter == 'All' 
              ? colorScheme.surfaceVariant.withOpacity(0.5)
              : colorScheme.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.filter_list_rounded, 
          size: 20, 
          color: _selectedClassFilter == 'All' ? colorScheme.onSurface : colorScheme.primary
        ),
      ),
      onSelected: (value) => setState(() => _selectedClassFilter = value),
      itemBuilder: (context) => _getClasses().map((c) => PopupMenuItem(
        value: c,
        child: Row(
          children: [
            if (_selectedClassFilter == c) Icon(Icons.check, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(c),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildWeeklyTab() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 8),
        TabBar(
          controller: _dayTabController,
          isScrollable: true,
          indicatorSize: TabBarIndicatorSize.label,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: colorScheme.primary, width: 3),
            insets: const EdgeInsets.symmetric(horizontal: 8),
          ),
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant.withOpacity(0.6),
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2),
          tabs: _days.map((day) => Tab(text: day.substring(0, 3).toUpperCase())).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _dayTabController,
            children: _days.map((day) => _buildDaySchedule(day)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDaySchedule(String day) {
    var periods = _timetable[day] ?? [];
    
    // Apply filter
    if (_selectedClassFilter != 'All') {
      periods = periods.where((p) => p['class_name'] == _selectedClassFilter).toList();
    }

    if (periods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_available_rounded, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedClassFilter == 'All' ? 'No classes scheduled' : 'No classes for $_selectedClassFilter', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const Text('Enjoy your free time!', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      itemCount: periods.length,
      itemBuilder: (context, index) {
        final period = periods[index];
        final todayIndex = DateTime.now().weekday - 1;
        final isToday = _days.indexOf(day) == todayIndex;
        final bool currentHighlight = _currentPeriod != null &&
            _currentPeriod!['id'] == period['id'] &&
            isToday;

        return _buildTimelineItem(period, currentHighlight, index == periods.length - 1);
      },
    );
  }

  Widget _buildTimelineItem(dynamic period, bool isLive, bool isLast) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = isLive ? colorScheme.primary : colorScheme.outline.withOpacity(0.3);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Column(
              children: [
                Text(
                  formatTime12hr(period['start_time']),
                  style: TextStyle(
                    fontWeight: isLive ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 13,
                    color: isLive ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatTime12hr(period['end_time']),
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isLive ? colorScheme.primary : Colors.transparent,
                    border: Border.all(color: accentColor, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: accentColor.withOpacity(0.3))),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLive ? colorScheme.primary.withOpacity(0.05) : colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isLive ? colorScheme.primary.withOpacity(0.2) : colorScheme.outline.withOpacity(0.1),
                  ),
                  boxShadow: isLive ? [
                    BoxShadow(color: colorScheme.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ] : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            period['subject_name'],
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isLive ? colorScheme.primary : colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isLive)
                          _buildBadge('LIVE', colorScheme.error),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildInfoChip(Icons.school_outlined, '${period['class_name']} - ${period['section_name']}'),
                        const SizedBox(width: 12),
                        _buildInfoChip(Icons.meeting_room_outlined, period['room_number'] ?? 'N/A'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamsTab() {
    var filteredExams = _exams;
    if (_selectedClassFilter != 'All') {
      filteredExams = _exams.where((e) => e['class_name'] == _selectedClassFilter).toList();
    }

    if (filteredExams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('No exams scheduled', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final myDuties = filteredExams.where((e) => e['duty_type'] == 'invigilator').toList();
    final classExams = filteredExams.where((e) => e['duty_type'] != 'invigilator').toList();

    // Group class exams by class
    Map<String, List<dynamic>> groupedByClass = {};
    for (var ex in classExams) {
      final key = ex['class_name'] ?? 'Other';
      if (!groupedByClass.containsKey(key)) groupedByClass[key] = [];
      groupedByClass[key]!.add(ex);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (myDuties.isNotEmpty) ...[
          _buildSubHeader('Invigilation Duties', Icons.security_rounded, Colors.orange),
          const SizedBox(height: 12),
          ...myDuties.map((exam) => _buildExamCard(exam, isDuty: true)).toList(),
          const SizedBox(height: 24),
        ],
        if (groupedByClass.isNotEmpty) ...[
          _buildSubHeader('Class Wise Schedule', Icons.grid_view_rounded, Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          ...groupedByClass.entries.map((entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
                child: Text(
                  'Class ${entry.key}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ...entry.value.map((exam) => _buildExamCard(exam)).toList(),
              const SizedBox(height: 12),
            ],
          )).toList(),
        ],
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSubHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: color.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildExamCard(dynamic exam, {bool isDuty = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDuty ? Colors.orange : colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBadge(isDuty ? 'DUTY' : 'EXAM', color),
                          Text(
                            formatDate(exam['exam_date']),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        exam['subject_name'],
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      Text(
                        '${exam['exam_name']} • Class ${exam['class_name']}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 16, color: color),
                            const SizedBox(width: 8),
                            Text(
                              '${formatTime12hr(exam['start_time'])} - ${formatTime12hr(exam['end_time'])}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            if (exam['section_name'] != null) ...[
                              Icon(Icons.grid_view_rounded, size: 16, color: color),
                              const SizedBox(width: 4),
                              Text(
                                'Sec: ${exam['section_name']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
            Icon(Icons.error_outline_rounded, size: 80, color: Theme.of(context).colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}

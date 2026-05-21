import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/app_drawer.dart';

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

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _dayTabController = TabController(length: _days.length, vsync: this, initialIndex: _getTodayIndex());
    _fetchTimetable();
    _fetchExams();
    _fetchCurrentPeriod();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchCurrentPeriod());
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

          setState(() {
            _timetable = grouped;
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
        if (mounted) setState(() => _exams = data['data']['timetable'] ?? []);
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
    final weekday = DateTime.now().weekday; // 1 = Monday, ..., 7 = Sunday
    if (weekday >= 7) return 0; // Default to Monday if Sunday
    return weekday - 1;
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
        title: const Text('Schedule', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _mainTabController,
              indicator: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
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
      drawer: const AppDrawer(currentRoute: 'Timetable'),
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
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _fetchTimetable();
                _fetchExams();
                _fetchCurrentPeriod();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
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
    final periods = _timetable[day] ?? [];
    if (periods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_available_rounded, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
            ),
            const SizedBox(height: 16),
            const Text('No classes scheduled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Enjoy your free day!', style: TextStyle(color: Colors.grey)),
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
          // Time Column
          SizedBox(
            width: 70,
            child: Column(
              children: [
                Text(
                  formatTime12hr(period['start_time']),
                  style: TextStyle(
                    fontWeight: isLive ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 12,
                    color: isLive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatTime12hr(period['end_time']),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          
          // Indicator Column
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
                  child: isLive 
                    ? Center(child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))
                    : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: accentColor,
                    ),
                  ),
              ],
            ),
          ),

          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLive ? colorScheme.primaryContainer.withOpacity(0.4) : colorScheme.surface,
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.school_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${period['class_name']} ${period['section_name']}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.meeting_room_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          period['room_number'] ?? 'N/A',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
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
    if (_exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('No upcoming exams', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Your exam schedule is clear.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final myDuties = _exams.where((e) => e['duty_type'] == 'invigilator').toList();
    final otherExams = _exams.where((e) => e['duty_type'] != 'invigilator').toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (myDuties.isNotEmpty) ...[
          _buildSubHeader('My Invigilation Duties', Icons.security_rounded, Colors.orange),
          const SizedBox(height: 12),
          ...myDuties.map((exam) => _buildExamCard(exam)).toList(),
          const SizedBox(height: 24),
        ],
        if (otherExams.isNotEmpty) ...[
          _buildSubHeader('Class & Subject Schedule', Icons.calendar_month_rounded, Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          ...otherExams.map((exam) => _buildExamCard(exam)).toList(),
        ],
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: color.withOpacity(0.8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: color.withOpacity(0.2))),
      ],
    );
  }

  Widget _buildExamCard(dynamic exam) {
    final colorScheme = Theme.of(context).colorScheme;
    final isInvigilation = exam['duty_type'] == 'invigilator';
    final isClassTeacher = exam['duty_type'] == 'class_teacher';
    
    Color dutyColor = colorScheme.primary;
    String dutyLabel = 'Subject Marker';
    IconData dutyIcon = Icons.edit_note_rounded;

    if (isInvigilation) {
      dutyColor = Colors.orange;
      dutyLabel = 'Invigilator';
      dutyIcon = Icons.security_rounded;
    } else if (isClassTeacher) {
      dutyColor = Colors.teal;
      dutyLabel = 'Class Overview';
      dutyIcon = Icons.visibility_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                color: dutyColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: dutyColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(dutyIcon, size: 12, color: dutyColor),
                                const SizedBox(width: 4),
                                Text(
                                  dutyLabel.toUpperCase(),
                                  style: TextStyle(color: dutyColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatDate(exam['exam_date']),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        exam['subject_name'],
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      Text(
                        '${exam['exam_name']} • ${exam['class_name']}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              '${formatTime12hr(exam['start_time'])} - ${formatTime12hr(exam['end_time'])}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Spacer(),
                            if (exam['section_name'] != null) ...[
                              Icon(Icons.grid_view_rounded, size: 16, color: colorScheme.primary),
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
}
